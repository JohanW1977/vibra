#include "vibrabackend.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QStandardPaths>
#include <QDebug>
#include <QRegularExpression>

// ── Constructor / Destructor ─────────────────────────────────────────────────

VibraBackend::VibraBackend(QObject *parent)
    : QObject(parent)
{
    // Populate device list immediately so the settings combo is not empty.
    refreshDevices();
}

VibraBackend::~VibraBackend()
{
    cleanup();
}

// ── Public invokables ────────────────────────────────────────────────────────

void VibraBackend::startListening(const QString &deviceId, int seconds)
{
    if (m_state == QLatin1String("listening") ||
        m_state == QLatin1String("identifying")) {
        return;
    }

    const QString vibraBin = vibrabinary();
    if (vibraBin.isEmpty()) {
        Q_EMIT errorOccurred(tr("vibra binary not found. Please rebuild the plasmoid."));
        return;
    }

    cleanup();
    setState(QStringLiteral("listening"));
    setStatusText(tr("Listening…"));

    // ── pw-record  ──────────────────────────────────────────────────────────
    // Capture signed 16-bit PCM at 44100 Hz, mono, for `seconds` seconds,
    // then close so vibra gets EOF and can send the fingerprint.
    //
    // pw-record --target <node.name or id>
    //           --rate 44100 --channels 1 --format s16
    //           --latency 100ms
    //           --duration <seconds>
    //           -   (dash = write raw PCM to stdout)
    //
    // If the deviceId is "default" or empty we omit --target so PipeWire
    // uses whatever the user's default source is.

    m_captureProcess = new QProcess(this);
    // Use parec (PulseAudio record) instead of pw-record
    // parec correctly honours source selection on PipeWire via libpulse
    m_captureProcess->setProgram(QStringLiteral("parec"));

    QStringList captureArgs;
    // parec uses --device to select the source
    if (!deviceId.isEmpty() && deviceId != QLatin1String("default")) {
        captureArgs << QStringLiteral("--device=") + deviceId;
    }
    captureArgs << QStringLiteral("--rate=44100")
                << QStringLiteral("--channels=1")
                << QStringLiteral("--format=s16le")
                << QStringLiteral("--latency-msec=100")
                << QStringLiteral("--raw");
    m_captureProcess->setArguments(captureArgs);

    // ── vibra ───────────────────────────────────────────────────────────────
    // Reads raw signed-16-bit PCM from stdin.
    // vibra --recognize --seconds <N> --rate 44100 --channels 1 --bits 16
    m_vibraProcess = new QProcess(this);
    m_vibraProcess->setProgram(vibraBin);
    m_vibraProcess->setArguments({
        QStringLiteral("--recognize"),
        QStringLiteral("--seconds"),   QString::number(seconds),
        QStringLiteral("--rate"),      QStringLiteral("44100"),
        QStringLiteral("--channels"),  QStringLiteral("1"),
        QStringLiteral("--bits"),      QStringLiteral("16")
    });

    // Pipe: parec stdout → vibra stdin
    m_captureProcess->setStandardOutputProcess(m_vibraProcess);

    connect(m_vibraProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &VibraBackend::onVibraFinished);
    connect(m_vibraProcess,
            &QProcess::errorOccurred,
            this, &VibraBackend::onVibraError);

    connect(m_captureProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &VibraBackend::onCaptureFinished);

    m_vibraProcess->start();
    m_captureProcess->start();

    if (!m_captureProcess->waitForStarted(3000)) {
        Q_EMIT errorOccurred(tr("Failed to start parec. Is PipeWire/PulseAudio installed?"));
        cleanup();
        setState(QStringLiteral("error"));
        return;
    }
    if (!m_vibraProcess->waitForStarted(3000)) {
        Q_EMIT errorOccurred(tr("Failed to start vibra binary."));
        cleanup();
        setState(QStringLiteral("error"));
        return;
    }

    setState(QStringLiteral("listening"));
    setStatusText(tr("Listening for %1 seconds…").arg(seconds));
}

void VibraBackend::stopListening()
{
    m_stopping = true;
    cleanup();
    m_stopping = false;
    setState(QStringLiteral("idle"));
    setStatusText(tr("Stopped."));
}

void VibraBackend::refreshDevices()
{
    // Use `pactl list sources short` — available on both PulseAudio and
    // PipeWire-pulse.  Output format (tab-separated):
    //   <index>  <name>  <module>  <sample-spec>  <state>
    if (m_pactlProcess) {
        m_pactlProcess->kill();
        m_pactlProcess->deleteLater();
        m_pactlProcess = nullptr;
    }

    m_pactlProcess = new QProcess(this);
    m_pactlProcess->setProgram(QStringLiteral("pactl"));
    m_pactlProcess->setArguments({ QStringLiteral("list"), QStringLiteral("sources"), QStringLiteral("short") });

    connect(m_pactlProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
        if (exitCode != 0) {
            // pactl failed — provide a single "default" entry
            m_deviceListJson = QStringLiteral(
                "[{\"id\":\"default\",\"name\":\"Default source\"}]");
            Q_EMIT deviceListChanged();
            return;
        }
        buildDeviceList(m_pactlProcess->readAllStandardOutput());
        m_pactlProcess->deleteLater();
        m_pactlProcess = nullptr;
    });

    m_pactlProcess->start();
}

// ── Private slots ────────────────────────────────────────────────────────────

void VibraBackend::onCaptureFinished(int exitCode, QProcess::ExitStatus)
{
    Q_UNUSED(exitCode)
    if (m_stopping) return;
    // pw-record finished → vibra will get EOF and finalize its result.
    setState(QStringLiteral("identifying"));
    setStatusText(tr("Identifying…"));
}

void VibraBackend::onVibraFinished(int exitCode, QProcess::ExitStatus)
{
    if (m_stopping) return;
    if (exitCode != 0) {
        const QString errOut = m_vibraProcess
            ? QString::fromUtf8(m_vibraProcess->readAllStandardError())
            : QString();
        Q_EMIT errorOccurred(tr("vibra exited with error: %1").arg(errOut));
        setState(QStringLiteral("error"));
        setStatusText(tr("Recognition failed."));
        cleanup();
        return;
    }

    const QByteArray output = m_vibraProcess
        ? m_vibraProcess->readAllStandardOutput()
        : QByteArray();

    cleanup();
    parseResult(output);
}

void VibraBackend::onVibraError(QProcess::ProcessError err)
{
    Q_UNUSED(err)
    if (m_stopping) return;
    Q_EMIT errorOccurred(tr("Process error: %1")
        .arg(m_vibraProcess ? m_vibraProcess->errorString() : QString()));
    setState(QStringLiteral("error"));
    setStatusText(tr("Process error."));
    cleanup();
}

// ── Private helpers ──────────────────────────────────────────────────────────

void VibraBackend::setState(const QString &s)
{
    if (m_state == s) return;
    m_state = s;
    Q_EMIT stateChanged();
}

void VibraBackend::setStatusText(const QString &t)
{
    if (m_statusText == t) return;
    m_statusText = t;
    Q_EMIT statusTextChanged();
}

QString VibraBackend::vibrabinary() const
{
    // Primary location: <plasmoid>/contents/bin/vibra
    // We resolve relative to this plugin's location via the application dir
    // or via a hardcoded well-known path.
    const QString plasmoidBase =
        QStringLiteral("%1/.local/share/plasma/plasmoids/org.kde.plasma.vibra")
            .arg(QDir::homePath());

    const QString bundled = plasmoidBase + QStringLiteral("/contents/bin/vibra");
    if (QFileInfo::exists(bundled) &&
        QFileInfo(bundled).isExecutable()) {
        return bundled;
    }

    // Fallback: system PATH (useful during development)
    const QString inPath =
        QStandardPaths::findExecutable(QStringLiteral("vibra"));
    return inPath;
}

void VibraBackend::parseResult(const QByteArray &jsonData)
{
    if (jsonData.trimmed().isEmpty()) {
        Q_EMIT errorOccurred(tr("No result returned from vibra."));
        setState(QStringLiteral("error"));
        setStatusText(tr("No match found."));
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);

    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        Q_EMIT errorOccurred(tr("Failed to parse vibra output: %1")
                               .arg(parseError.errorString()));
        setState(QStringLiteral("error"));
        setStatusText(tr("Parse error."));
        return;
    }

    const QJsonObject root  = doc.object();
    const QJsonObject track = root.value(QLatin1String("track")).toObject();

    if (track.isEmpty()) {
        // vibra returned valid JSON but no track — song not recognised
        setState(QStringLiteral("idle"));
        setStatusText(tr("No match found."));
        Q_EMIT errorOccurred(tr("Song not recognised."));
        return;
    }

    const QString title    = track.value(QLatin1String("title")).toString();
    const QString artist   = track.value(QLatin1String("subtitle")).toString();
    const QString trackUrl = track.value(QLatin1String("url")).toString();

    // Cover art: prefer the "coverarthq" image from the images array.
    QString coverUrl;
    const QJsonObject images = track.value(QLatin1String("images")).toObject();
    if (!images.isEmpty()) {
        // vibra/Shazam provides "coverarthq" and "coverart"
        coverUrl = images.value(QLatin1String("coverarthq")).toString();
        if (coverUrl.isEmpty())
            coverUrl = images.value(QLatin1String("coverart")).toString();
    }

    setState(QStringLiteral("found"));
    setStatusText(tr("Found: %1 — %2").arg(artist, title));

    Q_EMIT resultReady(title, artist, coverUrl, trackUrl,
                     QString::fromUtf8(jsonData));
}

void VibraBackend::buildDeviceList(const QByteArray &pactlOutput)
{
    // pactl list sources short → tab-separated:
    // index \t name \t module \t sample-spec \t state
    // We also run pw-dump to get node.description for friendly names.
    QJsonArray arr;

    QJsonObject defEntry;
    defEntry[QLatin1String("id")]   = QStringLiteral("default");
    defEntry[QLatin1String("name")] = tr("Default source");
    arr.append(defEntry);

    // Build name→description map from pw-dump
    QHash<QString, QString> descMap;
    QProcess pwDump;
    pwDump.setProgram(QStringLiteral("pw-dump"));
    pwDump.start();
    pwDump.waitForFinished(3000);
    if (pwDump.exitCode() == 0) {
        const QJsonDocument pwDoc = QJsonDocument::fromJson(pwDump.readAllStandardOutput());
        if (pwDoc.isArray()) {
            for (const QJsonValue &val : pwDoc.array()) {
                const QJsonObject obj = val.toObject();
                const QJsonObject props = obj.value(QLatin1String("info"))
                                            .toObject()
                                            .value(QLatin1String("props"))
                                            .toObject();
                const QString nodeName = props.value(QLatin1String("node.name")).toString();
                const QString nodeDesc = props.value(QLatin1String("node.description")).toString();
                if (!nodeName.isEmpty() && !nodeDesc.isEmpty())
                    descMap[nodeName] = nodeDesc;
            }
        }
    }

    // Parse pactl short output
    const QString text = QString::fromUtf8(pactlOutput);
    const QStringList lines = text.split(QLatin1Char('\n'), Qt::SkipEmptyParts);

    for (const QString &line : lines) {
        const QStringList cols = line.split(QLatin1Char('\t'));
        if (cols.size() < 2) continue;
        const QString name = cols.at(1).trimmed();
        if (name.isEmpty()) continue;

        // For monitor sources, look up the base output node's description
        QString lookupName = name;
        if (lookupName.endsWith(QLatin1String(".monitor")))
            lookupName.chop(8); // remove ".monitor"

        // Use pw-dump description if available, otherwise clean up the name
        QString label = descMap.value(lookupName);
        if (label.isEmpty()) label = descMap.value(name);
        if (label.isEmpty()) {
            // Fallback: clean up raw name
            label = name;
            label.remove(QRegularExpression(QStringLiteral("^(alsa_input|alsa_output|bluez_output|bluez_input)\\.")));
            label.remove(QRegularExpression(QStringLiteral("\\.(analog|mono|stereo|a2dp|headset|monitor).*$")));
            label.replace(QLatin1Char('_'), QLatin1Char(' '));
            label = label.trimmed();
            if (label.isEmpty()) label = name;
        }

        // Mark monitor sources
        if (name.contains(QLatin1String(".monitor")))
            label = tr("Monitor of ") + label;

        // Deduplicate
        QString finalLabel = label;
        int dupCount = 0;
        for (int i = 0; i < arr.size(); i++) {
            if (arr[i].toObject()[QLatin1String("name")].toString() == finalLabel)
                dupCount++;
        }
        if (dupCount > 0)
            finalLabel += QStringLiteral(" (%1)").arg(dupCount + 1);

        QJsonObject entry;
        entry[QLatin1String("id")]   = name;
        entry[QLatin1String("name")] = finalLabel;
        arr.append(entry);
    }

    m_deviceListJson = QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
    Q_EMIT deviceListChanged();
}

QString VibraBackend::loadHistory()
{
    const QString path = QDir::homePath() +
        QStringLiteral("/.local/share/plasma-shazam/history.json");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QStringLiteral("[]");
    return QString::fromUtf8(f.readAll());
}

bool VibraBackend::saveHistory(const QString &json)
{
    const QString dir  = QDir::homePath() +
        QStringLiteral("/.local/share/plasma-shazam");
    const QString path = dir + QStringLiteral("/history.json");
    QDir().mkpath(dir);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return false;
    f.write(json.toUtf8());
    return true;
}

QString VibraBackend::loadSettings()
{
    const QString path = QDir::homePath() +
        QStringLiteral("/.local/share/plasma-shazam/settings.json");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return QStringLiteral("{}");
    return QString::fromUtf8(f.readAll());
}

bool VibraBackend::saveSettings(const QString &json)
{
    const QString dir  = QDir::homePath() +
        QStringLiteral("/.local/share/plasma-shazam");
    const QString path = dir + QStringLiteral("/settings.json");
    QDir().mkpath(dir);
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return false;
    f.write(json.toUtf8());
    return true;
}

void VibraBackend::downloadFile(const QString &url, const QString &path)
{
    if (!m_nam) {
        m_nam = new QNetworkAccessManager(this);
    }
    QNetworkRequest request{QUrl(url)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, path]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            Q_EMIT downloadComplete(path, false);
            return;
        }
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly)) {
            Q_EMIT downloadComplete(path, false);
            return;
        }
        f.write(reply->readAll());
        f.close();
        Q_EMIT downloadComplete(path, true);
    });
}

void VibraBackend::sendNotification(const QString &title, const QString &artist,
                                    const QString &coverUrl, const QString &iconPath)
{
    // Download cover art to a temp file first, then send via DBus
    if (!m_nam) m_nam = new QNetworkAccessManager(this);

    QNetworkRequest request{QUrl(coverUrl)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_nam->get(request);

    const QString summary = artist + QStringLiteral(" - ") + title;

    connect(reply, &QNetworkReply::finished, this, [reply, summary, iconPath]() {
        reply->deleteLater();

        QString icon = QStringLiteral("audio-track");

        if (reply->error() == QNetworkReply::NoError) {
            QFile f(iconPath);
            if (f.open(QIODevice::WriteOnly)) {
                f.write(reply->readAll());
                f.close();
                icon = iconPath;
            }
        }

        // Parse artist, title and optional remix from summary
        // summary = "Artist - Title (Remix)" or "Artist - Title"
        QString notifSummary = summary;
        QString notifBody;

        // Split artist and rest at " - "
        const int dashPos = summary.indexOf(QStringLiteral(" - "));
        if (dashPos >= 0) {
            const QString artistPart = summary.left(dashPos);
            const QString titlePart  = summary.mid(dashPos + 3);

            // Check for optional remix/version in parentheses
            const QRegularExpression remixRe(QStringLiteral("^(.+?)\\s*(\\([^)]+\\))\\s*$"));
            const QRegularExpressionMatch m = remixRe.match(titlePart);
            if (m.hasMatch()) {
                notifSummary = artistPart;
                notifBody    = m.captured(1) + QLatin1Char('\n') + m.captured(2);
            } else {
                notifSummary = artistPart;
                notifBody    = titlePart;
            }
        }

        // Load image and scale to 200x200 for notification
        QImage img(icon);
        if (!img.isNull())
            img = img.scaled(200, 200, Qt::KeepAspectRatio, Qt::SmoothTransformation);

        QVariantMap hints;
        hints[QStringLiteral("urgency")] = QVariant::fromValue<uchar>(1);

        // Use image-path hint — simplest approach, Plasma supports it directly
        if (!icon.isEmpty() && QFile::exists(icon))
            hints[QStringLiteral("image-path")] = icon;

        // Send via org.freedesktop.Notifications DBus interface
        QDBusInterface iface(
            QStringLiteral("org.freedesktop.Notifications"),
            QStringLiteral("/org/freedesktop/Notifications"),
            QStringLiteral("org.freedesktop.Notifications")
        );

        iface.call(
            QStringLiteral("Notify"),
            QStringLiteral("Shazam Clone"),  // app_name
            (uint)0,                          // replaces_id
            icon,                             // app_icon — file path shows as large icon
            notifSummary,                     // summary (artist)
            notifBody,                        // body (title + optional remix)
            QStringList(),                    // actions
            hints,                            // hints
            5000                              // expire_timeout ms
        );
    });
}

bool VibraBackend::writeFile(const QString &path, const QString &content)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return false;
    f.write(content.toUtf8());
    return true;
}

void VibraBackend::cleanup()
{
    if (m_captureProcess) {
        m_captureProcess->kill();
        m_captureProcess->waitForFinished(1000);
        m_captureProcess->deleteLater();
        m_captureProcess = nullptr;
    }
    if (m_vibraProcess) {
        m_vibraProcess->kill();
        m_vibraProcess->waitForFinished(1000);
        m_vibraProcess->deleteLater();
        m_vibraProcess = nullptr;
    }
}

#pragma once

#include <QObject>
#include <QProcess>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QDBusInterface>
#include <QDBusArgument>
#include <QDBusVariant>
#include <QDBusConnection>
#include <QImage>
#include <QRegularExpression>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <qqml.h>

class VibraBackend : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString state          READ state          NOTIFY stateChanged)
    Q_PROPERTY(QString statusText     READ statusText     NOTIFY statusTextChanged)
    Q_PROPERTY(QString deviceListJson READ deviceListJson NOTIFY deviceListChanged)

public:
    explicit VibraBackend(QObject *parent = nullptr);
    ~VibraBackend() override;

    QString state()          const { return m_state; }
    QString statusText()     const { return m_statusText; }
    QString deviceListJson() const { return m_deviceListJson; }

    Q_INVOKABLE void startListening(const QString &deviceId, int seconds);
    Q_INVOKABLE QString loadHistory();
    Q_INVOKABLE bool    saveHistory(const QString &json);
    Q_INVOKABLE QString loadSettings();
    Q_INVOKABLE bool    saveSettings(const QString &json);
    Q_INVOKABLE bool    writeFile(const QString &path, const QString &content);
    Q_INVOKABLE void    downloadFile(const QString &url, const QString &path);
    Q_INVOKABLE void    sendNotification(const QString &title, const QString &artist, const QString &coverUrl, const QString &iconPath);
    Q_INVOKABLE void stopListening();
    Q_INVOKABLE void refreshDevices();

Q_SIGNALS:
    void stateChanged();
    void statusTextChanged();
    void deviceListChanged();

    void resultReady(const QString &title,
                     const QString &artist,
                     const QString &coverUrl,
                     const QString &trackUrl,
                     const QString &rawJson);

    void errorOccurred(const QString &message);
    void downloadComplete(const QString &path, bool success);

private Q_SLOTS:
    void onCaptureFinished(int exitCode, QProcess::ExitStatus status);
    void onVibraFinished(int exitCode, QProcess::ExitStatus status);
    void onVibraError(QProcess::ProcessError error);

private:
    void setState(const QString &s);
    void setStatusText(const QString &t);
    QString vibrabinary() const;
    void parseResult(const QByteArray &jsonData);
    void buildDeviceList(const QByteArray &pactlOutput);
    void cleanup();

    QString  m_state          { QStringLiteral("idle") };
    QString  m_statusText     { QStringLiteral("Ready") };
    QString  m_deviceListJson { QStringLiteral("[]") };

    QProcess *m_captureProcess { nullptr };
    QProcess *m_vibraProcess   { nullptr };
    QProcess *m_pactlProcess   { nullptr };
    bool      m_stopping        { false };
    QNetworkAccessManager *m_nam { nullptr };
};

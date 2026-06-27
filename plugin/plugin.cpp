#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include "vibrabackend.h"

class PlasmaShazamPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.vibra"));
        // Plasma 6 / Qt 6: register as a creatable QML type.
        // In QML: import org.kde.plasma.vibra; VibraBackend { id: backend }
        qmlRegisterType<VibraBackend>(uri, 1, 0, "VibraBackend");
    }
};

#include "plugin.moc"

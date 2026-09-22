#include <QApplication>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDebug>
#include <QLoggingCategory>

#include "apibridge.h"
#include "traybridge.h"
#include "themebridge.h"

void qmlMessageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
    Q_UNUSED(type)
    Q_UNUSED(ctx)
    fprintf(stderr, "[QML] %s\n", qPrintable(msg));
    fflush(stderr);
}

int main(int argc, char *argv[]) {
    qInstallMessageHandler(qmlMessageHandler);
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("Lazyio"));
    QApplication::setOrganizationName(QStringLiteral("Lazyio"));
#ifdef LAZYIO_VERSION
    QApplication::setApplicationVersion(QStringLiteral(LAZYIO_VERSION));
#else
    QApplication::setApplicationVersion(QStringLiteral("1.0.0"));
#endif
    QApplication::setWindowIcon(QIcon(QStringLiteral(":/resources/icons/png/lazyio-256.png")));
    QApplication::setQuitOnLastWindowClosed(false);

    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/PlusJakartaSans.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/MaterialSymbols.ttf"));

    ApiBridge api;
    TrayBridge tray;
    ThemeBridge theme;

    QQmlApplicationEngine engine;
    api.setEngine(engine.rootContext()->engine());
    engine.rootContext()->setContextProperty(QStringLiteral("Api"), &api);
    engine.rootContext()->setContextProperty(QStringLiteral("Tray"), &tray);
    engine.rootContext()->setContextProperty(QStringLiteral("Theme"), &theme);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, []() {
        qCritical() << "QML object creation failed!";
    });

    const QUrl url(QStringLiteral("qrc:/qml/Main.qml"));
    engine.load(url);
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Root objects empty. QML load failed.";
        return -1;
    }
    qDebug() << "QML loaded successfully.";

    if (QObject *root = engine.rootObjects().first()) {
        if (QWindow *window = qobject_cast<QWindow *>(root))
            tray.setWindow(window);
        QObject::connect(&tray, &TrayBridge::playPauseRequested, root, [root]() {
            QMetaObject::invokeMethod(root, "trayTogglePlay");
        });
        QObject::connect(&tray, &TrayBridge::nextRequested, root, [root]() {
            QMetaObject::invokeMethod(root, "trayNext");
        });
        QObject::connect(&tray, &TrayBridge::prevRequested, root, [root]() {
            QMetaObject::invokeMethod(root, "trayPrev");
        });
    }

    return app.exec();
}

#pragma once

#include <QObject>
#include <QPointer>
#include <QSystemTrayIcon>
#include <QWindow>

// System-tray + background behavior: minimize/close-to-tray, transport
// actions from the tray menu, and track-change notifications.
class TrayBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool quitting READ quitting NOTIFY quittingChanged)
    Q_PROPERTY(bool trayAvailable READ trayAvailable CONSTANT)
public:
    explicit TrayBridge(QObject *parent = nullptr);

    bool quitting() const { return m_quitting; }
    bool trayAvailable() const { return QSystemTrayIcon::isSystemTrayAvailable(); }

    void setWindow(QWindow *window);

public slots:
    void showWindow();
    void hideWindow();
    void toggleWindow();
    void updateTrack(const QString &title, const QString &artist);
    void setPlaying(bool playing);
    void notify(const QString &title, const QString &message);
    void requestQuit();

signals:
    void quittingChanged();
    void playPauseRequested();
    void nextRequested();
    void prevRequested();

private:
    void rebuildMenu();
    QSystemTrayIcon m_tray;
    QPointer<QWindow> m_window;
    bool m_quitting = false;
    bool m_playing = false;
    QString m_title;
    QString m_artist;
};

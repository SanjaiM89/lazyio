#include "traybridge.h"

#include <QAction>
#include <QApplication>
#include <QIcon>
#include <QMenu>

TrayBridge::TrayBridge(QObject *parent) : QObject(parent) {
    m_tray.setIcon(QIcon(QStringLiteral(":/resources/icons/png/lazyio-64.png")));
    m_tray.setToolTip(QStringLiteral("Lazyio — Lossless Audio"));
    rebuildMenu();
    QObject::connect(&m_tray, &QSystemTrayIcon::activated, this,
                     [this](QSystemTrayIcon::ActivationReason reason) {
                         if (reason == QSystemTrayIcon::Trigger)
                             toggleWindow();
                     });
    if (QSystemTrayIcon::isSystemTrayAvailable())
        m_tray.show();
}

void TrayBridge::setWindow(QWindow *window) {
    m_window = window;
}

void TrayBridge::showWindow() {
    if (m_window) {
        m_window->show();
        m_window->raise();
        m_window->requestActivate();
    }
}

void TrayBridge::hideWindow() {
    if (m_window)
        m_window->hide();
}

void TrayBridge::toggleWindow() {
    if (!m_window)
        return;
    if (m_window->isVisible())
        hideWindow();
    else
        showWindow();
}

void TrayBridge::updateTrack(const QString &title, const QString &artist) {
    m_title = title;
    m_artist = artist;
    m_tray.setToolTip(title.isEmpty() ? QStringLiteral("Lazyio — Lossless Audio")
                                      : title + QStringLiteral(" — ") + artist);
}

void TrayBridge::setPlaying(bool playing) {
    m_playing = playing;
    rebuildMenu();
}

void TrayBridge::notify(const QString &title, const QString &message) {
    if (QSystemTrayIcon::supportsMessages())
        m_tray.showMessage(title, message, QSystemTrayIcon::Information, 4000);
}

void TrayBridge::requestQuit() {
    m_quitting = true;
    emit quittingChanged();
    QApplication::quit();
}

void TrayBridge::rebuildMenu() {
    QMenu *menu = new QMenu();
    QAction *titleAct = menu->addAction(m_title.isEmpty() ? QStringLiteral("Lazyio") : m_title);
    titleAct->setEnabled(false);
    menu->addSeparator();
    QAction *playAct = menu->addAction(m_playing ? QStringLiteral("Pause") : QStringLiteral("Play"));
    QObject::connect(playAct, &QAction::triggered, this, &TrayBridge::playPauseRequested);
    QAction *nextAct = menu->addAction(QStringLiteral("Next"));
    QObject::connect(nextAct, &QAction::triggered, this, &TrayBridge::nextRequested);
    QAction *prevAct = menu->addAction(QStringLiteral("Previous"));
    QObject::connect(prevAct, &QAction::triggered, this, &TrayBridge::prevRequested);
    menu->addSeparator();
    QAction *showAct = menu->addAction(QStringLiteral("Show / Hide"));
    QObject::connect(showAct, &QAction::triggered, this, &TrayBridge::toggleWindow);
    QAction *quitAct = menu->addAction(QStringLiteral("Quit"));
    QObject::connect(quitAct, &QAction::triggered, this, &TrayBridge::requestQuit);
    QMenu *old = m_tray.contextMenu();
    m_tray.setContextMenu(menu);
    delete old;
}

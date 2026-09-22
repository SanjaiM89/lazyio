#pragma once

#include <QJSValue>
#include <QJSEngine>
#include <QNetworkAccessManager>
#include <QObject>
#include <QVariantMap>

class ApiBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
public:
    explicit ApiBridge(QObject *parent = nullptr);

    void setEngine(QJSEngine *engine) { m_engine = engine; }

    QString baseUrl() const { return m_baseUrl; }
    void setBaseUrl(const QString &url);

    Q_INVOKABLE QString streamUrl(const QString &songId) const;
    Q_INVOKABLE QString videoStreamUrl(const QString &songId) const;
    Q_INVOKABLE QString wsUrl() const;

    Q_INVOKABLE void get(const QString &path, const QVariantMap &params, const QJSValue &cb);
    Q_INVOKABLE void post(const QString &path, const QVariantMap &params, const QVariantMap &body, const QJSValue &cb);
    Q_INVOKABLE void del(const QString &path, const QVariantMap &params, const QJSValue &cb);
    Q_INVOKABLE void upload(const QString &path, const QStringList &files, const QJSValue &done, const QJSValue &progress);

signals:
    void baseUrlChanged();

private:
    QUrl buildUrl(const QString &path, const QVariantMap &params) const;
    QJSValue toJS(const QVariant &v);
    void invokeCb(const QJSValue &cb, const QVariant &arg);
    void send(QNetworkAccessManager::Operation op, const QUrl &url,
              const QByteArray &body, const QString &contentType, const QJSValue &cb);

    QJSEngine *m_engine = nullptr;
    QNetworkAccessManager m_nam;
    QString m_baseUrl = QStringLiteral("http://localhost:8000");
};

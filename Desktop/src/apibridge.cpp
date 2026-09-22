#include "apibridge.h"

#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkReply>
#include <QUrlQuery>

ApiBridge::ApiBridge(QObject *parent) : QObject(parent) {}

void ApiBridge::setBaseUrl(const QString &url) {
    QString clean = url.trimmed();
    while (clean.endsWith('/'))
        clean.chop(1);
    if (clean != m_baseUrl) {
        m_baseUrl = clean;
        emit baseUrlChanged();
    }
}

QString ApiBridge::streamUrl(const QString &songId) const {
    return m_baseUrl + QStringLiteral("/api/stream/") + songId + QStringLiteral("?quality=original");
}

QString ApiBridge::videoStreamUrl(const QString &songId) const {
    return m_baseUrl + QStringLiteral("/api/stream/") + songId + QStringLiteral("?type=video");
}

QString ApiBridge::wsUrl() const {
    QString u = m_baseUrl;
    if (u.startsWith(QStringLiteral("https://")))
        u.replace(QStringLiteral("https://"), QStringLiteral("wss://"));
    else
        u.replace(QStringLiteral("http://"), QStringLiteral("ws://"));
    return u + QStringLiteral("/ws");
}

QUrl ApiBridge::buildUrl(const QString &path, const QVariantMap &params) const {
    QUrl url(m_baseUrl + QStringLiteral("/api") + path);
    if (!params.isEmpty()) {
        QUrlQuery q;
        for (auto it = params.constBegin(); it != params.constEnd(); ++it) {
            if (it.value().typeId() == QMetaType::QVariantList) {
                const QVariantList list = it.value().toList();
                for (const QVariant &v : list)
                    q.addQueryItem(it.key(), v.toString());
            } else {
                q.addQueryItem(it.key(), it.value().toString());
            }
        }
        url.setQuery(q);
    }
    return url;
}

void ApiBridge::invokeCb(const QJSValue &cb, const QVariant &arg) {
    if (cb.isCallable()) {
        QJSValueList args;
        args.reserve(1);
        args.append(toJS(arg));
        cb.call(args);
    }
}

QJSValue ApiBridge::toJS(const QVariant &v) {
    if (m_engine)
        return m_engine->toScriptValue(v);
    return QJSValue(v.toString());
}

void ApiBridge::send(QNetworkAccessManager::Operation op, const QUrl &url,
                     const QByteArray &body, const QString &contentType, const QJSValue &cb) {
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(30 * 60 * 1000);
    QNetworkReply *reply = nullptr;
    if (op == QNetworkAccessManager::GetOperation)
        reply = m_nam.get(req);
    else if (op == QNetworkAccessManager::PostOperation)
        reply = m_nam.post(req, body);
    else if (op == QNetworkAccessManager::DeleteOperation)
        reply = m_nam.deleteResource(req);
    else
        return;
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, cb]() {
        QVariantMap result;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
        const bool ok = reply->error() == QNetworkReply::NoError;
        QVariant data;
        if (!raw.isEmpty()) {
            QJsonParseError err;
            const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
            if (err.error == QJsonParseError::NoError)
                data = doc.toVariant();
            else
                data = QString::fromUtf8(raw);
        }
        result.insert(QStringLiteral("ok"), ok);
        result.insert(QStringLiteral("status"), status);
        result.insert(QStringLiteral("data"), data);
        if (!ok)
            result.insert(QStringLiteral("error"), reply->errorString());
        invokeCb(cb, result);
        reply->deleteLater();
    });
}

void ApiBridge::get(const QString &path, const QVariantMap &params, const QJSValue &cb) {
    send(QNetworkAccessManager::GetOperation, buildUrl(path, params), {}, QStringLiteral("application/json"), cb);
}

void ApiBridge::post(const QString &path, const QVariantMap &params, const QVariantMap &body, const QJSValue &cb) {
    const QByteArray payload = QJsonDocument(QJsonObject::fromVariantMap(body)).toJson(QJsonDocument::Compact);
    send(QNetworkAccessManager::PostOperation, buildUrl(path, params), payload, QStringLiteral("application/json"), cb);
}

void ApiBridge::del(const QString &path, const QVariantMap &params, const QJSValue &cb) {
    send(QNetworkAccessManager::DeleteOperation, buildUrl(path, params), {}, QStringLiteral("application/json"), cb);
}

void ApiBridge::upload(const QString &path, const QStringList &files, const QJSValue &done, const QJSValue &progress) {
    QHttpMultiPart *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    QMimeDatabase mimeDb;
    qint64 total = 0;
    for (const QString &local : files) {
        QString filePath = QUrl(local).isLocalFile() ? QUrl(local).toLocalFile() : local;
        QFile *file = new QFile(filePath, multi);
        if (!file->open(QIODevice::ReadOnly)) {
            delete file;
            continue;
        }
        QHttpPart part;
        part.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"files\"; filename=\"%1\"").arg(QFileInfo(filePath).fileName()));
        part.setHeader(QNetworkRequest::ContentTypeHeader, mimeDb.mimeTypeForFile(filePath).name());
        part.setBodyDevice(file);
        multi->append(part);
        total += QFileInfo(filePath).size();
    }
    QNetworkRequest req(buildUrl(path, {}));
    req.setTransferTimeout(30 * 60 * 1000);
    QNetworkReply *reply = m_nam.post(req, multi);
    multi->setParent(reply);
    QObject::connect(reply, &QNetworkReply::uploadProgress, this, [this, progress, total](qint64 sent, qint64) {
        if (progress.isCallable() && total > 0)
            invokeCb(progress, QVariant(static_cast<int>((sent * 100) / total)));
    });
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, done]() {
        QVariantMap result;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
        const bool ok = reply->error() == QNetworkReply::NoError;
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
        result.insert(QStringLiteral("ok"), ok);
        result.insert(QStringLiteral("status"), status);
        result.insert(QStringLiteral("data"), err.error == QJsonParseError::NoError ? doc.toVariant() : QString::fromUtf8(raw));
        if (!ok)
            result.insert(QStringLiteral("error"), reply->errorString());
        invokeCb(done, result);
        reply->deleteLater();
    });
}

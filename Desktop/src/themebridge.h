#pragma once

#include <QObject>
#include <QColor>
#include <QVariant>

class ThemeBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariant background READ background CONSTANT)
    Q_PROPERTY(QVariant surface READ surface CONSTANT)
    Q_PROPERTY(QVariant surfaceLow READ surfaceLow CONSTANT)
    Q_PROPERTY(QVariant surfaceContainer READ surfaceContainer CONSTANT)
    Q_PROPERTY(QVariant surfaceHigh READ surfaceHigh CONSTANT)
    Q_PROPERTY(QVariant surfaceHighest READ surfaceHighest CONSTANT)
    Q_PROPERTY(QVariant primary READ primary CONSTANT)
    Q_PROPERTY(QVariant primaryContainer READ primaryContainer CONSTANT)
    Q_PROPERTY(QVariant onPrimary READ onPrimary CONSTANT)
    Q_PROPERTY(QVariant onPrimaryContainer READ onPrimaryContainer CONSTANT)
    Q_PROPERTY(QVariant secondary READ secondary CONSTANT)
    Q_PROPERTY(QVariant secondaryContainer READ secondaryContainer CONSTANT)
    Q_PROPERTY(QVariant tertiary READ tertiary CONSTANT)
    Q_PROPERTY(QVariant onSurface READ onSurface CONSTANT)
    Q_PROPERTY(QVariant onVariant READ onVariant CONSTANT)
    Q_PROPERTY(QVariant outline READ outline CONSTANT)
    Q_PROPERTY(QVariant error READ error CONSTANT)
    Q_PROPERTY(QString fontMain READ fontMain CONSTANT)
    Q_PROPERTY(QString fontIcon READ fontIcon CONSTANT)
    Q_PROPERTY(int sideWidth READ sideWidth CONSTANT)
    Q_PROPERTY(int queueWidth READ queueWidth CONSTANT)
    Q_PROPERTY(int headerH READ headerH CONSTANT)
    Q_PROPERTY(int playerH READ playerH CONSTANT)
public:
    explicit ThemeBridge(QObject *parent = nullptr) : QObject(parent) {}
    QVariant background() const { return QColor("#151316"); }
    QVariant surface() const { return QColor("#151316"); }
    QVariant surfaceLow() const { return QColor("#1d1b1e"); }
    QVariant surfaceContainer() const { return QColor("#211f22"); }
    QVariant surfaceHigh() const { return QColor("#2c292c"); }
    QVariant surfaceHighest() const { return QColor("#373437"); }
    QVariant primary() const { return QColor("#ffb4a4"); }
    QVariant primaryContainer() const { return QColor("#e0836e"); }
    QVariant onPrimary() const { return QColor("#5a1b0d"); }
    QVariant onPrimaryContainer() const { return QColor("#5e1e10"); }
    QVariant secondary() const { return QColor("#ffb3b0"); }
    QVariant secondaryContainer() const { return QColor("#862025"); }
    QVariant tertiary() const { return QColor("#ffb3b6"); }
    QVariant onSurface() const { return QColor("#e7e1e5"); }
    QVariant onVariant() const { return QColor("#dac1bc"); }
    QVariant outline() const { return QColor("#a28c87"); }
    QVariant error() const { return QColor("#ffb4ab"); }
    QString fontMain() const { return QStringLiteral("Plus Jakarta Sans"); }
    QString fontIcon() const { return QStringLiteral("Material Symbols Outlined"); }
    int sideWidth() const { return 256; }
    int queueWidth() const { return 320; }
    int headerH() const { return 64; }
    int playerH() const { return 80; }

    Q_INVOKABLE QString fmtTime(qreal s) const {
        if (std::isnan(s) || s < 0) return QStringLiteral("0:00");
        int m = static_cast<int>(s) / 60;
        int sec = static_cast<int>(s) % 60;
        return QStringLiteral("%1:%2").arg(m).arg(sec, 2, 10, QChar('0'));
    }
};

#include "freechpage.h"
#include "ui_freechpage.h"

#include "clientmodel.h"
#include "clientversion.h"
#include "init.h"
#include "guiutil.h"
#include "qrdialog.h"
#include "sync.h"
#include "wallet/wallet.h"
#include "walletmodel.h"

FreechPage::FreechPage(const PlatformStyle *platformStyle, QWidget *parent) :
    QWidget(parent),
    ui(new Ui::FreechPage),
    clientModel(0),
    walletModel(0)
{
    ui->setupUi(this);
}

FreechPage::~FreechPage()
{
    delete ui;
}

void FreechPage::setClientModel(ClientModel *model)
{
    this->clientModel = model;
    if(model) {
    }
}

void FreechPage::setWalletModel(WalletModel *model)
{
    this->walletModel = model;
}
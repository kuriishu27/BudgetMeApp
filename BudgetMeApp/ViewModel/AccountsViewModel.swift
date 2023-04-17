//
//  AccountsViewModel.swift
//  BudgetMeApp
//
//  Created by Christian Leovido on 24/03/2020.
//  Copyright © 2020 Christian Leovido. All rights reserved.
//

import Foundation
import Moya
import RxCocoa
import RxMoya
import RxSwift

struct AccountsViewModel: ViewModelBlueprint {
  typealias Model = AccountComposite

  let provider: MoyaProvider<STAccountService>

  let isLoading: PublishSubject<Bool>
  let dataSource: BehaviorRelay<[AccountComposite]>
  let errorPublisher: PublishSubject<Error>
  let disposeBag: DisposeBag

  init(provider: MoyaProvider<STAccountService> = MoyaNetworkManagerFactory.makeManager()) {
    self.provider = provider
    isLoading = PublishSubject()
    dataSource = BehaviorRelay(value: [])
    errorPublisher = PublishSubject()
    disposeBag = DisposeBag()
  }

  func refreshData() {
    getAllAccounts()
      .do(onNext: { _ in
        self.isLoading.onNext(true)
      })
      .flatMap(fetchAllAccounts)
      .subscribe { event in
        switch event {
        case let .next(accountComposite):
          self.dataSource.accept(accountComposite)
        case let .error(error):
          self.errorPublisher.onNext(error)
        case .completed:
          self.isLoading.onNext(false)
        }
      }
      .disposed(by: disposeBag)
  }

  func fetchAllAccounts(account: [STAccount]) -> Observable<[AccountComposite]> {
    let request: (STAccount) -> Observable<AccountComposite> = { account in

      Observable.zip(self.getBalance(accountId: account.accountUid),
                     self.getIdentifiers(accountId: account.accountUid))
        .map { balance, identifiers in
          AccountComposite(account: account, balance: balance, identifiers: identifiers)
        }
    }

    let requests = account.map(request)

    return Observable.merge(requests)
      .toArray()
      .asObservable()
  }
}

extension AccountsViewModel {
  func getAllAccounts() -> Observable<[STAccount]> {
    let obs = provider.rx.request(.browseAccounts)
      .filterSuccessfulStatusAndRedirectCodes()
      .map([STAccount].self, atKeyPath: "accounts")
      .asObservable()
      .share(replay: 1, scope: .whileConnected)

    return obs
  }

  func getBalance(accountId: String) -> Observable<STBalance> {
    let obs = provider.rx.request(.getBalance(accountId: accountId))
      .filterSuccessfulStatusAndRedirectCodes()
      .map(STBalance.self)
      .asObservable()
      .share(replay: 1, scope: .whileConnected)

    return obs
  }

  func getIdentifiers(accountId: String) -> Observable<STAccountIdentifiers> {
    let observable = provider.rx.request(.getIdentifiers(accountId: accountId))
      .filterSuccessfulStatusAndRedirectCodes()
      .map(STAccountIdentifiers.self)
      .asObservable()
      .share(replay: 1, scope: .whileConnected)

    return observable
  }

  func getStatementPeriods(accountId: String) -> Observable<AccountStatementPeriods> {
    let observable = provider.rx.request(.getAvailableStatementPeriods(accountId: accountId))
      .filterSuccessfulStatusAndRedirectCodes()
      .map(AccountStatementPeriods.self, atKeyPath: "periods")
      .asObservable()
      .share(replay: 1, scope: .whileConnected)

    return observable
  }

  func getConfirmationOfFunds(accountId: String) -> Observable<ConfirmationOfFundsResponse> {
    let observable = provider.rx.request(.getConfirmationOfFunds(accountId: accountId))
      .filterSuccessfulStatusAndRedirectCodes()
      .map(ConfirmationOfFundsResponse.self)
      .asObservable()
      .share(replay: 1, scope: .whileConnected)

    return observable
  }
}

extension AccountsViewModel {
  func downloadPDFStatement(accountId: String, yearMonth: String) -> Completable {
    let observable = provider.rx.request(.downloadStatementPDF(accountId: accountId,
                                                               yearMonth: yearMonth))
      .filterSuccessfulStatusAndRedirectCodes()
      .asCompletable()

    return observable
  }

  func downloadStatementPDF(accountId: String, start: DateTime, end: DateTime) -> Completable {
    let obs = provider.rx.request(.downloadStatementPDFForDateRange(accountId: accountId,
                                                                    start: start,
                                                                    end: end))
      .filterSuccessfulStatusAndRedirectCodes()
      .asCompletable()

    return obs
  }

  func downloadCSVStatement(accountId: String, yearMonth: String) -> Completable {
    let observable = provider.rx.request(.downloadStatementCSV(accountId: accountId,
                                                               yearMonth: yearMonth))
      .filterSuccessfulStatusAndRedirectCodes()
      .asCompletable()

    return observable
  }

  func downloadStatementCSV(accountId: String, start: DateTime, end: DateTime) -> Completable {
    let obs = provider.rx.request(.downloadStatementCSVForDateRange(accountId: accountId,
                                                                    start: start,
                                                                    end: end))
      .filterSuccessfulStatusAndRedirectCodes()
      .asCompletable()

    return obs
  }
}

//
//  TransactionsViewModel.swift
//  BudgetMeApp
//
//  Created by Christian Leovido on 23/03/2020.
//  Copyright © 2020 Christian Leovido. All rights reserved.
//

import Foundation
import Moya
import RxCocoa
import RxDataSources
import RxMoya
import RxSwift

extension TransactionsViewModel: CurrencyFormattable {}

struct TransactionsViewModel: ViewModelBlueprint {
  typealias Model = TransactionSectionData

  var isLoading: PublishSubject<Bool> = PublishSubject()
  var dataSource: BehaviorRelay<[TransactionSectionData]> = BehaviorRelay(value: [])

  let provider: MoyaProvider<STTransactionFeedService>
  let errorPublisher: PublishSubject<Error>

  // outputs
  let dateRange: PublishSubject<String>

  let disposeBag: DisposeBag

  init(provider: MoyaProvider<STTransactionFeedService> = MoyaNetworkManagerFactory.makeManager(),
       accountId _: String)
  {
    self.provider = provider
    errorPublisher = PublishSubject()
    disposeBag = DisposeBag()
    dateRange = PublishSubject()
  }

  func makeTransactionRequest(start: DateTime, end: DateTime) -> Observable<[STTransactionFeed]> {
    provider.rx.request(.getWeeklyTransactions(accountId: Session.shared.accountId,
                                               categoryId: "c4ed84e4-8cc9-4a3b-8df5-85996f67f2db",
                                               startDate: start, endDate: end))
      .do(onSubscribe: {
        self.isLoading.onNext(true)
      })
      .filterSuccessfulStatusCodes()
      .map([STTransactionFeed].self, atKeyPath: "feedItems")
      .asObservable()
      .share(replay: 1, scope: .whileConnected)
  }

  func updateDataSource(startDate: DateTime, endDate: DateTime) {
    makeTransactionRequest(start: startDate, end: endDate)
      .map(makeTransactionSectionData)
      .subscribe { event in
        switch event {
        case let .next(txs):
          self.dataSource.accept(txs)
        case let .error(error):
          self.errorPublisher.onNext(error)
        case .completed:
          self.isLoading.onNext(false)
        }
      }
      .disposed(by: disposeBag)
  }

  func refreshData(with dateTime: DateTime) {
    let endDate = calculateNextWeek(startDate: dateTime)!
    updateDateRange(dateTime: dateTime)
    updateDataSource(startDate: dateTime, endDate: endDate)
  }

  func refreshData() {
    isLoading.onNext(true)

    provider.rx.request(.browseTransactions(accountId: Session.shared.accountId,
                                            categoryId: "c4ed84e4-8cc9-4a3b-8df5-85996f67f2db",
                                            changesSince: Date().toStringDateFormat()))
      .filterSuccessfulStatusCodes()
      .map([STTransactionFeed].self, atKeyPath: "feedItems")
      .map(makeTransactionSectionData)
      .subscribe { event in
        switch event {
        case let .success(transactionSectionData):

          self.dataSource.accept(transactionSectionData)
          self.isLoading.onNext(false)

        case let .error(error):

          self.errorPublisher.onNext(error)
          self.isLoading.onNext(false)
        }
      }
      .disposed(by: disposeBag)
  }
}

extension TransactionsViewModel {
  private func calculateNextWeek(startDate: String) -> String? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    guard let newDate = dateFormatter.date(from: startDate) else { return nil }
    guard let endDate = Calendar.current.date(byAdding: .day, value: 7, to: newDate) else { return nil }

    let endDateString = dateFormatter.string(from: endDate)

    return endDateString
  }

  func updateDateRange(dateTime: DateTime) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    guard let startDate = dateFormatter.date(from: dateTime) else { return }
    guard let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) else { return }

    dateFormatter.dateFormat = "dd/MM"

    let startDateString = dateFormatter.string(from: startDate)
    let endDateString = dateFormatter.string(from: endDate)

    dateRange.onNext(startDateString + " - " + endDateString)
  }
}

extension TransactionsViewModel {
  func makeTransactionSectionData(_ txs: [STTransactionFeed]) -> [TransactionSectionData] {
    let incomeSection = TransactionSectionData(header: TransactionType.income.rawValue.capitalized,
                                               items: txs.filter { $0.direction == .IN })

    let expensesSection = TransactionSectionData(header: TransactionType.expense.rawValue.capitalized,
                                                 items: txs.filter { $0.direction == .OUT })

    let items = [incomeSection,
                 expensesSection]

    return items
  }
}

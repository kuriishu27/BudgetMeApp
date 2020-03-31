//
//  AccountViewModelTests.swift
//  BudgetMeAppTests
//
//  Created by Christian Leovido on 27/03/2020.
//  Copyright © 2020 Christian Leovido. All rights reserved.
//

import XCTest
import RxSwift
import RxCocoa
import RxTest
@testable import BudgetMeApp

class AccountViewModelTests: XCTestCase {

    var accountViewModel: AccountsViewModel!

    var disposeBag: DisposeBag!
    var scheduler: TestScheduler!

    override func setUp() {

        disposeBag = DisposeBag()
        self.scheduler = TestScheduler(initialClock: 0)
    }

    override func tearDown() {
        accountViewModel = nil
    }

    func testGetIdentifiers() {

        accountViewModel = AccountsViewModel(provider: makeMoyaSuccessStub(type: .identifiers))

        let identifiersObserver = scheduler.createObserver(STAccountIdentifiers.self)

        accountViewModel.getIdentifiers(accountId: UUID().uuidString)
            .bind(to: identifiersObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertTrue(!identifiersObserver.events.isEmpty)

    }
    func testGetAccountStatementPeriods() {

        accountViewModel = AccountsViewModel(provider: makeMoyaSuccessStub(type: .statementPeriods))

        let accountStatementObserver = scheduler.createObserver(AccountStatementPeriods.self)

        accountViewModel.getStatementPeriods(accountId: UUID().uuidString)
            .bind(to: accountStatementObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertTrue(!accountStatementObserver.events.isEmpty)

    }
    func testSetupAccountComposite() {

        accountViewModel = AccountsViewModel()

        let compositeObserver = scheduler.createObserver(AccountComposite.self)

        accountViewModel.setupAccountComposite(account: STAccount(accountUid: "", defaultCategory: "", currency: .GBP, createdAt: ""))
            .bind(to: compositeObserver)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertTrue(compositeObserver.events.isEmpty)

    }
    func testDataSourceError() {

        accountViewModel = AccountsViewModel()

        let errorMock = scheduler.createObserver(Error.self)
        accountViewModel.errorPublisher.asObserver()
            .bind(to: errorMock)
            .disposed(by: disposeBag)

        scheduler.createColdObservable([.error(20, MockError.unknown)])
            .bind(to: accountViewModel.errorPublisher)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertTrue(!errorMock.events.isEmpty)

    }

    func testDataSource() {

        accountViewModel = AccountsViewModel()

        let dataSourceMock = scheduler.createObserver([AccountComposite].self)
        accountViewModel.dataSource
            .bind(to: dataSourceMock)
            .disposed(by: disposeBag)


        let account = STAccount(accountUid: "",
        defaultCategory: "",
        currency: .GBP,
        createdAt: Date().description)

        let balance = STBalance(clearedBalance: CurrencyAndAmount(currency: .GBP, minorUnits: 10000),
                                effectiveBalance: CurrencyAndAmount(currency: .GBP, minorUnits: 10000),
                                pendingTransactions: CurrencyAndAmount(currency: .GBP, minorUnits: 0),
                                acceptedOverdraft: CurrencyAndAmount(currency: .GBP, minorUnits: 0),
                                amount: CurrencyAndAmount(currency: .GBP, minorUnits: 10000))

        let identifiers = STAccountIdentifiers(accountIdentifier: "", bankIdentifier: "", iban: "", bic: "", accountIdentifiers: [])

        let randomAccounts = [AccountComposite(account: account, balance: balance, identifiers: identifiers)]

        scheduler.createColdObservable([.next(15, randomAccounts)])
            .bind(to: accountViewModel.dataSource)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(dataSourceMock.events, [.next(0, []),
                                               .next(15, randomAccounts)])

    }

}

private enum MockError: Equatable, Error {
    case unknown
}

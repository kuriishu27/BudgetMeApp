//
//  LoginViewTests.swift
//  BudgetMeAppTests
//
//  Created by Christian Leovido on 06/04/2020.
//  Copyright © 2020 Christian Leovido. All rights reserved.
//

@testable import BudgetMeApp
import Moya
import RxCocoa
import RxSwift
import RxTest
import XCTest

class LoginViewTests: XCTestCase {
    var loginViewModel: LoginViewModel!
    var scheduler: TestScheduler!
    var disposeBag: DisposeBag!

    override func setUp() {
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        loginViewModel = nil
        scheduler = nil
        disposeBag = nil
    }

    func testIsEmailTextFieldValid() {
        let provider: MoyaProvider<STAuthentication> = makeMoyaSuccessStub(type: .auth)
        loginViewModel = LoginViewModel(provider: provider)

        scheduler = TestScheduler(initialClock: 0)
        let mockIsValid = scheduler.createObserver(Bool.self)

        var mockEmailTextFieldValues: Observable<String>

        mockEmailTextFieldValues = scheduler.createHotObservable([.next(0, "s"),
                                                                  .next(10, "s"),
                                                                  .next(11, "st"),
                                                                  .next(12, "st@"),
                                                                  .next(13, "st")]).asObservable()

        let mockButton = UIButton()

        let output = loginViewModel.transform(input: LoginViewModel.Input(
            emailTextFieldChanged: mockEmailTextFieldValues,
            passwordTextFieldChanged: Observable.of("")
        )
        )

        output.isEmailTextFieldValid
            .drive(mockIsValid)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(mockIsValid.events, [.next(0, false),
                                            .next(10, false),
                                            .next(11, false),
                                            .next(12, true),
                                            .next(13, false)])
    }

    func testIsPasswordTextFieldValid() {
        let provider: MoyaProvider<STAuthentication> = makeMoyaSuccessStub(type: .auth)
        loginViewModel = LoginViewModel(provider: provider)

        scheduler = TestScheduler(initialClock: 0)
        let mockIsValid = scheduler.createObserver(Bool.self)

        var mockEmailTextFieldValues: Observable<String>

        mockEmailTextFieldValues = scheduler.createHotObservable([.next(0, "p"),
                                                                  .next(10, "pa"),
                                                                  .next(11, "pas"),
                                                                  .next(20, "password123")]).asObservable()

        let mockButton = UIButton()

        let output = loginViewModel.transform(input: LoginViewModel.Input(
            emailTextFieldChanged: Observable.of("something@something.com"),
            passwordTextFieldChanged: mockEmailTextFieldValues
        )
        )

        output.isValid
            .drive(mockIsValid)
            .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(mockIsValid.events, [.next(0, false),
                                            .next(10, false),
                                            .next(11, false),
                                            .next(20, true)])
    }

    private var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    enum STAuthenticationSuccessTestCases: String {
        case auth
    }

    private func makeMoyaSuccessStub<T: TargetType>(type: STAuthenticationSuccessTestCases) -> MoyaProvider<T> {
        #if DEBUG
            let url = bundle.url(forResource: "authentication_success_" + type.rawValue, withExtension: "json")!
            let data = try! Data(contentsOf: url)

            let serverEndpointSuccess = { (target: T) -> Endpoint in
                Endpoint(url: URL(target: target).absoluteString,
                         sampleResponseClosure: { .networkResponse(200, data) },
                         method: target.method,
                         task: target.task,
                         httpHeaderFields: target.headers)
            }

            let serverStubSuccess = MoyaProvider<T>(
                endpointClosure: serverEndpointSuccess,
                stubClosure: MoyaProvider.immediatelyStub,
                plugins: [
                    AuthPlugin(tokenClosure: { Session.shared.token }),
                ]
            )

            return serverStubSuccess

        #endif
    }
}

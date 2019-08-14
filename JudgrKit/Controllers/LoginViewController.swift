//
//  LoginViewController.swift
//  Judgr
//
//  Created by Willis Plummer on 7/29/19.
//  Copyright © 2019 Willis Plummer. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift

private var jwtKeychain = Keychain(service: "com.judgr.jwt-token")

struct LoginPayload: Encodable {
    let email: String
    let password: String
}

struct Environment {
    var loginApiRequest: (LoginPayload) -> SignalProducer<(Data, URLResponse), Error> = {
        var request = URLRequest(url: URL(string: "https://9354e589.ngrok.io/login")!)
        request.httpMethod = "POST"
        let jsonData = try? JSONEncoder().encode($0)
        
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return URLSession.shared.reactive
            .data(with: request)
    }
    var setJwtToken = { jwtKeychain["jwt"] = $0 }
}

var Current = Environment()

struct AuthenticatedUser: Decodable {
    let name: String
}

// TODO: Sigin Button Is Enabled Output based on if email and password fields are valid using combineLatest
// TODO: Login request failure should emit an error that then shows an alert in the view

func loginViewModel(
    emailInputChanged: Signal<String, Never>,
    emailInputEditingDidEnd: Signal<Void, Never>,
    passwordInputChanged: Signal<String, Never>,
    passwordInputEditingDidEnd: Signal<Void, Never>,
    loginButtonTapped: Signal<Void, Never>
    ) -> (
    showAlertWithFormValues: Signal<(String, String), Never>,
    passwordInputBecomeFirstResponder: Signal<Void, Never>,
    setJwtTokenAndSetRootViewControllerToHome: Signal<String?, Never>,
    loadingIndicatorIsAnimating: Signal<Bool, Never>
    ) {
        let formValues: Signal<(String, String), Never> = Signal.combineLatest(emailInputChanged, passwordInputChanged)
        
        let passwordInputBecomeFirstResponder = emailInputEditingDidEnd
        
        let login = Signal.merge(loginButtonTapped, passwordInputEditingDidEnd)
        
        let setJwtTokenAndSetRootViewControllerToHome: Signal<String?, Never> = login
            .withLatest(from: formValues)
            .map { $1 }
            .flatMap(.latest) {
                Current
                    .loginApiRequest(LoginPayload(email: $0, password: $1))
                    .materializeResults()
            }
            .map { result in
                if let error = result.error {
                    print("ERROR: \(error)")
                } else {
                    if let (_, httpResponse) = result.value as? (Data, HTTPURLResponse), let fields = httpResponse.allHeaderFields as? [String : String]  {
                        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: httpResponse.url!)
                        for cookie in cookies {
                            if cookie.name == "JWT-Cookie" {
                                return cookie.value
                            }
                            print("name: \(cookie.name) value: \(cookie.value)")
                        }
                        
                        print("RESPONSE: \(httpResponse)")
                    }
                }
                return Optional.none
        }
        
        let loadingIndicatorIsAnimating = Signal.merge(
            login.map { _ in true },
            setJwtTokenAndSetRootViewControllerToHome.map { _ in false }
        )
        
        let showAlertWithFormValues: Signal<(String, String), Never> = formValues
        
        
        return (
            showAlertWithFormValues: showAlertWithFormValues,
            passwordInputBecomeFirstResponder: passwordInputBecomeFirstResponder,
            setJwtTokenAndSetRootViewControllerToHome: setJwtTokenAndSetRootViewControllerToHome,
            loadingIndicatorIsAnimating: loadingIndicatorIsAnimating
        )
}

public class LoginViewController: UIViewController {
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Login"
        self.view.backgroundColor = .white
        UIButton.appearance().tintColor = .blue
        
        let emailInput = UITextField()
        emailInput.borderStyle = .roundedRect
        emailInput.contentVerticalAlignment = .center
        emailInput.textAlignment = .center
        emailInput.placeholder = "Email"
        emailInput.keyboardType = .emailAddress
        emailInput.autocapitalizationType = .none
        emailInput.returnKeyType = .next
        
        let passwordInput = UITextField()
        passwordInput.borderStyle = .roundedRect
        passwordInput.contentVerticalAlignment = .center
        passwordInput.textAlignment = .center
        passwordInput.placeholder = "Password"
        passwordInput.isSecureTextEntry = true
        passwordInput.returnKeyType = .continue

        let signInButton = UIButton() |> buttonStyle
        signInButton.setTitle("Sign In", for: .normal)
        
        let forgotPasswordButton = UIButton()
        forgotPasswordButton.setTitle("Forgot Password?", for: .normal)
        forgotPasswordButton.setTitleColor(.blue, for: .normal)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordButtonTapped), for: .touchUpInside)
        
        let loadingIndicator = UIActivityIndicatorView(style: .gray)

        let rootStackView = UIStackView(arrangedSubviews: [
            emailInput,
            passwordInput,
            signInButton,
            forgotPasswordButton,
            loadingIndicator,
            UIView(),
            ])
        rootStackView.axis = .vertical
        rootStackView.alignment = .center
        rootStackView.spacing = 10
        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStackView)
        
        NSLayoutConstraint.activate([
            rootStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            rootStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        
        let (
        showAlertWithFormValues: _,
        passwordInputBecomeFirstResponder: passwordInputBecomeFirstResponder,
        setJwtTokenAndSetRootViewControllerToHome: setJwtTokenAndSetRootViewControllerToHome,
        loadingIndicatorIsAnimating: loadingIndicatorIsAnimating
            ) = loginViewModel(
                emailInputChanged: emailInput.reactive.continuousTextValues,
                emailInputEditingDidEnd: emailInput.reactive.controlEvents(.editingDidEndOnExit).map { _ in () },
                passwordInputChanged: passwordInput.reactive.continuousTextValues,
                passwordInputEditingDidEnd: passwordInput.reactive.controlEvents(.editingDidEndOnExit).map { _ in () },
                loginButtonTapped: signInButton.reactive.controlEvents(.touchUpInside).map { _ in () }
        )
        
        loadingIndicator.reactive.isAnimating <~ loadingIndicatorIsAnimating
        
        passwordInput.reactive.becomeFirstResponder <~ passwordInputBecomeFirstResponder
        
        setJwtTokenAndSetRootViewControllerToHome
            .observe(on: UIScheduler())
            .observeValues { [weak self] in self?.setJwtTokenAndGoHome($0) }
        }
    
    private func setJwtTokenAndGoHome(_ jwtToken: String?) {
        guard let token = jwtToken else { return }
        Current.setJwtToken(token)
        let homeView = UIViewController()
        homeView.view.backgroundColor = .white
        homeView.title = "Home"
        
        self.navigationController?.setViewControllers([homeView], animated: true)
    }
    
    @objc private func forgotPasswordButtonTapped() {
        let forgotPasswordView = ForgotPasswordViewController()
        navigationController?.pushViewController(forgotPasswordView, animated: true)
    }
}

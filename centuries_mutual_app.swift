// MARK: - AppDelegate.swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = SplashViewController()
        window?.makeKeyAndVisible()
        
        return true
    }
}

// MARK: - SceneDelegate.swift (iOS 13+)
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = SplashViewController()
        window?.makeKeyAndVisible()
    }
}

// MARK: - SplashViewController.swift
import UIKit

class SplashViewController: UIViewController {
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Auto transition to main screen after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.navigateToMainScreen()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0)
        
        // Logo setup
        logoImageView.image = UIImage(systemName: "leaf.fill") // Placeholder for wheat logo
        logoImageView.tintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1.0)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title setup
        titleLabel.text = "Centuries Mutual"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .light)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func navigateToMainScreen() {
        let mainVC = MainViewController()
        let navController = UINavigationController(rootViewController: mainVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}

// MARK: - MainViewController.swift
import UIKit

class MainViewController: UIViewController {
    
    private let backgroundImageView = UIImageView()
    private let overlayView = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0)
        
        // Background setup (placeholder for forest background)
        backgroundImageView.image = UIImage(systemName: "tree.fill")
        backgroundImageView.tintColor = UIColor.systemBrown.withAlphaComponent(0.3)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Overlay for better text readability
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Logo setup
        logoImageView.image = UIImage(systemName: "leaf.fill")
        logoImageView.tintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1.0)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title setup
        titleLabel.text = "Centuries Mutual"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .light)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Login button setup
        loginButton.setTitle("Login", for: .normal)
        loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        loginButton.setTitleColor(UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0), for: .normal)
        loginButton.backgroundColor = UIColor(red: 240/255, green: 235/255, blue: 210/255, alpha: 1.0)
        loginButton.layer.cornerRadius = 25
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        view.addSubview(backgroundImageView)
        view.addSubview(overlayView)
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(loginButton)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            loginButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            loginButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func loginButtonTapped() {
        let loginVC = LoginViewController()
        navigationController?.pushViewController(loginVC, animated: true)
    }
}

// MARK: - LoginViewController.swift
import UIKit

class LoginViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let backgroundImageView = UIImageView()
    private let overlayView = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let googleSignInButton = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let createAccountButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardObservers()
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        // Add back button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .white
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 240/255, green: 235/255, blue: 210/255, alpha: 1.0)
        
        // Navigation bar styling
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        
        // Background setup
        backgroundImageView.image = UIImage(systemName: "tree.fill")
        backgroundImageView.tintColor = UIColor.systemBrown.withAlphaComponent(0.2)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Overlay
        overlayView.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Logo setup
        logoImageView.image = UIImage(systemName: "leaf.fill")
        logoImageView.tintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1.0)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title setup
        titleLabel.text = "Centuries Mutual"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .light)
        titleLabel.textColor = UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Email text field
        setupTextField(emailTextField, placeholder: "Email:", isSecure: false)
        
        // Password text field
        setupTextField(passwordTextField, placeholder: "Password:", isSecure: true)
        
        // Google Sign In button
        googleSignInButton.setTitle("Sign in with Google", for: .normal)
        googleSignInButton.setImage(UIImage(systemName: "globe"), for: .normal)
        googleSignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        googleSignInButton.setTitleColor(.darkGray, for: .normal)
        googleSignInButton.tintColor = .darkGray
        googleSignInButton.backgroundColor = .white
        googleSignInButton.layer.cornerRadius = 25
        googleSignInButton.layer.borderWidth = 1
        googleSignInButton.layer.borderColor = UIColor.lightGray.cgColor
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        googleSignInButton.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        
        // Forgot password button
        forgotPasswordButton.setTitle("Forgot Password", for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        forgotPasswordButton.setTitleColor(UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0), for: .normal)
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        
        // Create account button
        createAccountButton.setTitle("Create An Account", for: .normal)
        createAccountButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        createAccountButton.setTitleColor(UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0), for: .normal)
        createAccountButton.translatesAutoresizingMaskIntoConstraints = false
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(backgroundImageView)
        view.addSubview(overlayView)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(logoImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(emailTextField)
        contentView.addSubview(passwordTextField)
        contentView.addSubview(googleSignInButton)
        contentView.addSubview(forgotPasswordButton)
        contentView.addSubview(createAccountButton)
        
        setupConstraints()
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String, isSecure: Bool) {
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 8
        textField.isSecureTextEntry = isSecure
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            emailTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 20),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            googleSignInButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 30),
            googleSignInButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            googleSignInButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 50),
            
            forgotPasswordButton.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 30),
            forgotPasswordButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            
            createAccountButton.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 30),
            createAccountButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            
            createAccountButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func googleSignInTapped() {
        // Implement Google Sign In logic
        print("Google Sign In tapped")
    }
    
    @objc private func forgotPasswordTapped() {
        // Implement forgot password logic
        print("Forgot Password tapped")
    }
    
    @objc private func createAccountTapped() {
        // Implement create account logic
        print("Create Account tapped")
    }
}

// MARK: - Extensions for better organization

extension UIColor {
    static let centuriesGreen = UIColor(red: 76/255, green: 106/255, blue: 89/255, alpha: 1.0)
    static let centuriesGold = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1.0)
    static let centuriesBackground = UIColor(red: 240/255, green: 235/255, blue: 210/255, alpha: 1.0)
}

// MARK: - Info.plist Configuration
/*
Add these keys to your Info.plist file:

<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
<key>UIMainStoryboardFile</key>
<string></string>
<key>UISceneDelegate</key>
<dict>
    <key>UISceneClassName</key>
    <string>UIWindowScene</string>
    <key>UISceneDelegateClassName</key>
    <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
</dict>
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
*/
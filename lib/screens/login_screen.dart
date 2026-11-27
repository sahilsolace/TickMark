import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../widgets/custom_header_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.isRegistered<AuthController>()
      ? Get.find<AuthController>()
      : Get.put<AuthController>(AuthController());

  @override
  void initState() {
    super.initState();
    _authController.checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          // Custom Window Header
          const CustomHeaderBar(
            isLoginHeader: true,
          ),

          // Remaining screen area
          Expanded(
            child: Row(
              children: [
                // Left side - Image (50%)
                Expanded(
                  flex: 1,
                  child: SizedBox.expand(
                    child: Image.asset(
                      'assets/loginImg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Right side - Login Form (50%)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 400,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                'assets/tickmark.png',
                                height: 65,
                              ),
                              const SizedBox(height: 35),

                              const Text(
                                'Welcome Back!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                'Sign in to Continue to TickMark',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 35),

                              TextField(
                                controller: _authController.emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'Enter Email',
                                  prefixIcon: Icon(Icons.email),
                                  border: OutlineInputBorder(),
                                ),
                              ),

                              const SizedBox(height: 20),

                              Obx(
                                () => TextField(
                                  controller: _authController.passwordController,
                                  obscureText: _authController.obscureText.value,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter Password',
                                    prefixIcon: const Icon(Icons.lock),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      onPressed: _authController.togglePasswordVisibility,
                                      icon: Icon(
                                        _authController.obscureText.value
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              SizedBox(
                                height: 50,
                                child: Obx(
                                  () => ElevatedButton(
                                    onPressed: _authController.isLoading.value ? null : _authController.login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF075B3A),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _authController.isLoading.value
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Login'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

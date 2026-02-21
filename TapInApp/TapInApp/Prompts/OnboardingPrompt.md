# Onboarding Flow — Implementation Prompt

## Overview

Build a complete onboarding experience for TapIn (UC Davis student app).
The onboarding is shown once on first launch, then never again.
After completing onboarding, the user lands on the main ContentView (News tab).

The flow supports three sign-in methods:
- Sign in with Apple
- Sign in with Google
- Phone Number (SMS OTP)

---

## App Architecture Notes

- SwiftUI, iOS 17+, MVVM pattern
- Global state lives in `AppState.swift` (@Observable singleton)
- After successful auth, set `AppState.shared.isAuthenticated = true`
- Gate the onboarding in `TapInAppApp.swift` — if not authenticated, show `OnboardingView`, else show `ContentView`
- Persist auth state in `UserDefaults` so the user stays logged in across launches

---

## File Structure to Create

```
TapInApp/
└── Onboarding/
    ├── OnboardingView.swift          # Root container — manages which step is shown
    ├── WelcomeView.swift             # Screen 1 — hero/splash
    ├── SignInOptionsView.swift       # Screen 2 — choose auth method
    ├── PhoneEntryView.swift          # Screen 3 — enter phone number
    ├── OTPVerificationView.swift     # Screen 4 — enter 6-digit code
    ├── ProfileSetupView.swift        # Screen 5 — name, email, year
    └── OnboardingViewModel.swift     # Shared state + auth logic for all screens
```

---

## Screen 1 — Welcome / Hero Screen

**File:** `WelcomeView.swift`

**Purpose:** First thing the user sees. Sets the tone. Single CTA to proceed.

**UI Components:**
- Full screen gradient background
- App logo / icon mark centered
- Bold headline + subtitle
- "Get Started" primary button (full width, pill shape)
- "Already have an account? Sign in" text link

**Design Reference (paste Stitch CSS/code below):**

```
/* PASTE SCREEN 1 STITCH CODE HERE */
<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>TapIn - Onboarding</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "primary": "#00d0ff",
                        "background-light": "#f5f8f8",
                        "background-dark": "#0f1f23",
                    },
                    fontFamily: {
                        "display": ["Plus Jakarta Sans", "sans-serif"]
                    },
                    borderRadius: {
                        "DEFAULT": "1rem",
                        "lg": "2rem",
                        "xl": "3rem",
                        "full": "9999px"
                    },
                },
            },
        }
    </script>
<style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
        }
        .cow-print-bg {
            background-image: url('{{DATA:IMAGE:IMAGE_4}}');
            background-size: cover;
            background-position: center;
        }
        .glass-effect {
            background: rgba(255, 255, 255, 0.8);
            backdrop-filter: blur(4px);
            border: 1px solid rgba(0, 0, 0, 0.1);
        }
    </style>
<style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
        }
        .cow-print-bg {
            background-image: url('{{DATA:IMAGE:IMAGE_4}}');
            background-size: cover;
            background-position: center;
        }
        .glass-effect {
            background: rgba(255, 255, 255, 0.8);
            backdrop-filter: blur(4px);
            border: 1px solid rgba(0, 0, 0, 0.1);
        }
    </style>
</head>
<body class="bg-background-light dark:bg-background-dark text-slate-900 dark:text-slate-100 antialiased overflow-hidden">
<!-- Main Container -->
<div class="relative flex h-screen w-full flex-col justify-between px-8 py-12 cow-print-bg"><div class="absolute inset-0 bg-white/40 pointer-events-none"></div>
<!-- Top Section: App Logo/Icon -->
<div class="flex flex-col items-center justify-center pt-20">
<div class="relative flex items-center justify-center size-24 bg-white/10 rounded-3xl glass-effect shadow-2xl shadow-primary/20"><span class="text-slate-900 text-5xl font-extrabold tracking-tighter">T</span><div class="absolute -z-10 size-16 bg-primary blur-2xl opacity-20"></div></div>
</div>
<!-- Middle Section: Hero Text -->
<div class="flex flex-col items-center text-center space-y-4">
<h1 class="text-4xl md:text-5xl font-extrabold leading-[1.1] tracking-tight max-w-[12ch] text-slate-900">
                Your campus, all in one place
            </h1>
<p class="text-lg font-medium leading-relaxed max-w-[280px] text-slate-700">
                News, events, and games — built for <span class="text-primary">UC Davis</span>
</p>
</div>
<!-- Bottom Section: CTAs -->
<div class="flex flex-col items-center w-full space-y-6 pb-4">
<!-- Primary CTA -->
<button class="group relative flex w-full max-w-sm cursor-pointer items-center justify-center overflow-hidden rounded-full h-16 bg-[#050a15] text-white text-lg font-bold transition-all hover:scale-[1.02] active:scale-[0.98]">
<span>Get Started</span>
<div class="absolute inset-0 bg-primary/10 opacity-0 group-hover:opacity-100 transition-opacity"></div>
</button>
<!-- Secondary CTA -->
<div class="flex flex-col items-center space-y-1">
<button class="text-sm font-medium hover:text-white transition-colors text-slate-600">
                    Already have an account? <span class="font-bold underline decoration-primary/50 underline-offset-4 text-slate-900">Sign in</span>
</button>
</div>
</div>
<!-- Decorative Elements -->

</div>
<!-- Hidden Map/Image references for compliance with requirements -->
<div class="hidden">
<img alt="Campus" data-alt="UC Davis campus aerial artistic view" src="https://lh3.googleusercontent.com/aida-public/AB6AXuAWw1tKvyEcVFvye13J4BsaW64Rf8vXvqTUtdBqnlA_WwPF-YRKJjrTfrSGul_eK-yb2w7nfdfamGKUWJefU8DWy8jqjUHSv0pm9n5_5beC-5YfbQvSs9Zp1l7uNiuOgIRCyq5_J6M5O9VZtqvzLMaGxNr6DN2LUYyLU8NlE8WaJQkIdvQPUfpSmhZbXz4XJabJA-0XQGiAK1B1cCcj1jGrC86LQnNfu3VTnaewWTy0spsIWpfOmRL6G5CZsaj2U5vD9NN1J4A7lYCP"/>
<div data-location="Davis, California" style=""></div>
</div>
</body></html>
```


---

## Screen 2 — Sign-In Options Screen

**File:** `SignInOptionsView.swift`

**Purpose:** User chooses how they want to authenticate.

**UI Components:**
- Back button (top left)
- Title: "Sign in to TapIn"
- Three auth buttons stacked:
  1. Continue with Google (white button, Google logo)
  2. Continue with Apple (black button, Apple logo) — use `SignInWithAppleButton` from `AuthenticationServices`
  3. Continue with Phone (outlined button, phone icon)
- Divider with "or" between social + phone options
- Privacy policy note at bottom

**Auth Actions:**
- Google → trigger Google Sign-In SDK flow
- Apple → trigger `ASAuthorizationAppleIDRequest`
- Phone → navigate to `PhoneEntryView`

**Design Reference (paste Stitch CSS/code below):**

```
/* PASTE SCREEN 2 STITCH CODE HERE */
<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>TapIn - Sign In</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
          darkMode: "class",
          theme: {
            extend: {
              colors: {
                "primary": "#00d0ff",
                "background-light": "#f5f8f8",
                "background-dark": "#0f1f23",
              },
              fontFamily: {
                "display": ["Plus Jakarta Sans"]
              },
              borderRadius: {"DEFAULT": "1rem", "lg": "2rem", "xl": "3rem", "full": "9999px"},
            },
          },
        }
    </script>
<style>
        .cow-pattern {
            background-color: transparent;
            background-image: radial-gradient(circle at 20% 30%, rgba(255, 255, 255, 0.03) 0%, rgba(255, 255, 255, 0.03) 10%, transparent 10.1%),
                              radial-gradient(circle at 80% 10%, rgba(255, 255, 255, 0.02) 0%, rgba(255, 255, 255, 0.02) 15%, transparent 15.1%),
                              radial-gradient(circle at 50% 90%, rgba(255, 255, 255, 0.03) 0%, rgba(255, 255, 255, 0.03) 20%, transparent 20.1%),
                              radial-gradient(circle at 90% 60%, rgba(255, 255, 255, 0.02) 0%, rgba(255, 255, 255, 0.02) 12%, transparent 12.1%),
                              radial-gradient(circle at 10% 75%, rgba(255, 255, 255, 0.02) 0%, rgba(255, 255, 255, 0.02) 8%, transparent 8.1%);
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background-light dark:bg-background-dark font-display text-slate-900 dark:text-slate-100 min-h-screen flex flex-col antialiased">
<!-- Background Pattern Overlay -->
<div class="fixed inset-0 pointer-events-none cow-pattern opacity-50 z-0"></div>
<div class="relative z-10 flex flex-col min-h-screen w-full max-w-md mx-auto px-6 py-8">
<!-- Header Section -->
<header class="flex items-center mb-10">
<button class="flex items-center justify-center size-10 rounded-full bg-slate-200/50 dark:bg-slate-800/50 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors duration-200">
<span class="material-symbols-outlined text-slate-900 dark:text-slate-100">arrow_back</span>
</button>
</header>
<!-- Welcome Text -->
<div class="mb-10">
<h1 class="text-4xl font-bold tracking-tight text-slate-900 dark:text-white mb-2">Sign in to TapIn</h1>
<p class="text-slate-600 dark:text-slate-400 text-lg">Choose how you want to continue</p>
</div>
<!-- Action Buttons -->
<div class="space-y-4 flex-grow">
<!-- Google Button -->
<button class="w-full h-[56px] flex items-center justify-center gap-3 bg-white text-slate-900 rounded-full font-bold text-base shadow-sm hover:bg-slate-50 active:scale-[0.98] transition-all border border-slate-200">
<svg class="w-6 h-6" viewbox="0 0 24 24">
<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"></path>
<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"></path>
<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"></path>
<path d="M12 5.38c1.62 0 3.06.56 4.21 1.66l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"></path>
</svg>
                Continue with Google
            </button>
<!-- Apple Button -->
<button class="w-full h-[56px] flex items-center justify-center gap-3 bg-slate-950 text-white rounded-full font-bold text-base hover:bg-black active:scale-[0.98] transition-all">
<svg class="w-6 h-6" fill="currentColor" viewbox="0 0 24 24">
<path d="M17.05 20.28c-.96.95-2.05 2.22-3.4 2.22s-1.82-.84-3.38-.84-2.08.82-3.35.82-2.31-1.34-3.34-2.83c-2.11-3.05-2.28-7.79-.69-10.24 1.1-1.7 2.85-2.77 4.54-2.77 1.29 0 2.5.89 3.29.89s2.15-.99 3.65-.84c1.11.04 2.16.51 3 1.5-2.45 1.48-2.05 4.98.42 6.1-.9 2.08-1.95 4.19-3.74 5.99zM12.03 5.41c-.08-2.34 1.94-4.32 4.21-4.41.22 2.65-2.3 4.77-4.21 4.41z"></path>
</svg>
                Continue with Apple
            </button>
<!-- Divider -->
<div class="flex items-center gap-4 py-4">
<div class="h-px flex-1 bg-slate-200 dark:bg-slate-800"></div>
<span class="text-sm font-medium text-slate-400 dark:text-slate-500 uppercase tracking-widest">or</span>
<div class="h-px flex-1 bg-slate-200 dark:bg-slate-800"></div>
</div>
<!-- Phone Button (Ghost Style) -->
<button class="w-full h-[56px] flex items-center justify-center gap-3 bg-transparent border-2 border-primary/40 dark:border-primary/20 text-slate-900 dark:text-slate-100 rounded-full font-bold text-base hover:bg-primary/5 active:scale-[0.98] transition-all">
<span class="material-symbols-outlined text-primary">smartphone</span>
                Continue with Phone
            </button>
</div>
<!-- Footer Legal Text -->
<footer class="mt-12 text-center">
<p class="text-slate-500 dark:text-slate-500 text-xs leading-relaxed max-w-[280px] mx-auto">
                By continuing, you agree to our 
                <a class="text-primary hover:underline font-medium" href="#">Terms of Service</a> 
                &amp; 
                <a class="text-primary hover:underline font-medium" href="#">Privacy Policy</a>
</p>
</footer>
<!-- Bottom Spacer for Home Indicator on iOS -->
<div class="h-4"></div>
</div>
<!-- Decorative Organic Shape (Cow print inspiration) -->
<div class="fixed -bottom-20 -right-20 size-64 bg-primary/5 dark:bg-primary/10 rounded-full blur-3xl pointer-events-none z-0"></div>
<div class="fixed -top-20 -left-20 size-80 bg-slate-400/5 dark:bg-slate-500/5 rounded-full blur-3xl pointer-events-none z-0"></div>
</body></html>
```

---

## Screen 3 — Phone Number Entry Screen

**File:** `PhoneEntryView.swift`

**Purpose:** User enters their phone number to receive an SMS code.

**UI Components:**
- Back button (top left)
- Title: "Enter your number"
- Subtitle: "We'll send you a verification code"
- Country code selector (flag + dial code) + phone number text field in one row
- "SMS rates may apply" note
- "Send Code" button — disabled until a valid number is entered, activates on input

**Logic:**
- On tap "Send Code" → call SMS/OTP service (Firebase Auth or Twilio)
- On success → navigate to `OTPVerificationView` passing the phone number

**Design Reference (paste Stitch CSS/code below):**

```
/* PASTE SCREEN 3 STITCH CODE HERE */

<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>TapIn - Phone Entry</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "primary": "#00d0ff",
                        "background-light": "#f5f8f8",
                        "background-dark": "#0f1f23",
                    },
                    fontFamily: {
                        "display": ["Plus Jakarta Sans", "sans-serif"]
                    },
                    borderRadius: {
                        "DEFAULT": "1rem",
                        "lg": "2rem",
                        "xl": "3rem",
                        "full": "9999px"
                    },
                },
            },
        }
    </script>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background-light dark:bg-background-dark font-display text-slate-900 dark:text-slate-100 min-h-screen flex flex-col">
<!-- Top Navigation -->
<nav class="flex items-center px-6 py-4">
<button class="flex items-center justify-center size-10 rounded-full hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors">
<span class="material-symbols-outlined text-2xl">arrow_back</span>
</button>
</nav>
<!-- Main Content Area -->
<main class="flex-1 flex flex-col px-8 pt-8 max-w-md mx-auto w-full">
<!-- Header Section -->
<header class="mb-10">
<h1 class="text-4xl font-extrabold tracking-tight mb-3">
                Enter your number
            </h1>
<p class="text-slate-500 dark:text-slate-400 text-lg font-medium leading-relaxed">
                We'll send you a verification code
            </p>
</header>
<!-- Input Section -->
<div class="space-y-6">
<div class="group relative flex items-center bg-white dark:bg-slate-800/50 border-2 border-slate-200 dark:border-slate-700 focus-within:border-primary dark:focus-within:border-primary transition-all duration-200 rounded-2xl h-20 px-4 overflow-hidden">
<!-- Country/Dial Code Selector -->
<button class="flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors shrink-0">
<span class="text-2xl">🇺🇸</span>
<span class="font-bold text-lg text-slate-700 dark:text-slate-200">+1</span>
<span class="material-symbols-outlined text-slate-400 text-sm">keyboard_arrow_down</span>
</button>
<!-- Vertical Divider -->
<div class="w-[1px] h-10 bg-slate-200 dark:bg-slate-700 mx-3"></div>
<!-- Phone Input -->
<input autofocus="" class="w-full bg-transparent border-none focus:ring-0 text-2xl font-bold placeholder:text-slate-300 dark:placeholder:text-slate-600 text-slate-900 dark:text-white" placeholder="000 000 0000" type="tel"/>
</div>
<!-- Disclaimer -->
<p class="text-sm text-center text-slate-400 dark:text-slate-500 font-medium px-4">
                Standard SMS rates may apply
            </p>
</div>
<!-- Spacer to push button to bottom if not enough content -->
<div class="flex-1"></div>
<!-- Footer / Action Area -->
<footer class="py-10">
<!-- Brand Logo or App Name Subtle (Optional) -->
<div class="flex justify-center mb-6">
<div class="flex items-center gap-2 opacity-30">
<div class="size-6 bg-primary rounded-lg flex items-center justify-center">
<span class="material-symbols-outlined text-background-dark text-xs font-bold">bolt</span>
</div>
<span class="text-sm font-bold tracking-widest uppercase">TapIn</span>
</div>
</div>
<!-- Main CTA -->
<button class="w-full bg-primary hover:bg-primary/90 text-background-dark font-extrabold text-lg py-5 rounded-full shadow-lg shadow-primary/20 transition-all active:scale-[0.98]">
                Send Code
            </button>
</footer>
</main>
<!-- Visual Polish / Background Elements -->
<div class="fixed top-0 right-0 -z-10 w-64 h-64 bg-primary/5 rounded-full blur-3xl pointer-events-none"></div>
<div class="fixed bottom-0 left-0 -z-10 w-96 h-96 bg-primary/10 rounded-full blur-3xl pointer-events-none opacity-50"></div>
</body></html>

```

---

## Screen 4 — OTP Verification Screen

**File:** `OTPVerificationView.swift`

**Purpose:** User enters the 6-digit code sent to their phone.

**UI Components:**
- Back button (top left)
- Title: "Check your texts"
- Subtitle showing the masked phone number
- Row of 6 individual digit input boxes (rounded squares, large, auto-advance on input)
- "Resend code" link with countdown timer (e.g. "Resend in 0:30")
- "Verify" button — activates once all 6 boxes are filled

**Logic:**
- Auto-advance focus to next box on digit entry
- On "Verify" → validate OTP with auth service
- On success → navigate to `ProfileSetupView`
- On failure → shake animation on boxes + error message

**Design Reference (paste Stitch CSS/code below):**

```
/* PASTE SCREEN 4 STITCH CODE HERE */

<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>TapIn - Verify Your Number</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "primary": "#00d0ff",
                        "background-light": "#f5f8f8",
                        "background-dark": "#0f1f23",
                    },
                    fontFamily: {
                        "display": ["Plus Jakarta Sans", "sans-serif"]
                    },
                    borderRadius: {
                        "DEFAULT": "1rem",
                        "lg": "2rem",
                        "xl": "3rem",
                        "full": "9999px"
                    },
                },
            },
        }
    </script>
<style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
        }
        /* Hide arrows in number input */
        input::-webkit-outer-spin-button,
        input::-webkit-inner-spin-button {
            -webkit-appearance: none;
            margin: 0;
        }
        input[type=number] {
            -moz-appearance: textfield;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background-light dark:bg-background-dark text-slate-900 dark:text-slate-100 min-h-screen flex flex-col">
<!-- Top Navigation -->
<nav class="flex items-center px-4 py-6">
<button class="flex items-center justify-center size-12 rounded-full hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors">
<span class="material-symbols-outlined text-slate-900 dark:text-slate-100" style="font-size: 28px;">
                arrow_back
            </span>
</button>
</nav>
<!-- Content Area -->
<main class="flex-grow flex flex-col px-6">
<!-- Header -->
<header class="mt-4 mb-10">
<h1 class="text-4xl font-extrabold tracking-tight mb-3">
                Check your texts
            </h1>
<p class="text-slate-500 dark:text-slate-400 text-lg leading-relaxed">
                Enter the 6-digit code sent to <span class="font-semibold text-slate-900 dark:text-white">+1 (555) 000-0000</span>
</p>
</header>
<!-- OTP Input Group -->
<div class="flex justify-between gap-2 sm:gap-4 mb-8">
<input autocomplete="one-time-code" class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
<input class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
<input class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
<input class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
<input class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
<input class="w-full aspect-square text-center text-2xl font-bold bg-slate-100 dark:bg-slate-800/50 border-2 border-transparent focus:border-primary focus:ring-0 rounded-2xl transition-all outline-none" maxlength="1" placeholder="•" type="number"/>
</div>
<!-- Timer / Resend -->
<div class="flex flex-col items-center">
<p class="text-slate-500 dark:text-slate-400 font-medium text-sm">
                Resend code in <span class="text-primary">0:30</span>
</p>
<button class="mt-4 text-primary font-semibold text-sm opacity-50 cursor-not-allowed">
                Resend SMS
            </button>
</div>
</main>
<!-- Sticky Footer Action -->
<footer class="p-6 pb-12">
<button class="w-full bg-primary text-background-dark font-extrabold text-lg py-5 rounded-full hover:brightness-110 active:scale-[0.98] transition-all shadow-lg shadow-primary/20">
            Verify
        </button>
<!-- App Indicator Hint (iOS style) -->
<div class="mt-8 flex justify-center">
<div class="w-32 h-1.5 bg-slate-300 dark:bg-slate-700 rounded-full"></div>
</div>
</footer>
<!-- Abstract decorative background element for premium feel -->
<div class="fixed top-[-10%] right-[-10%] w-[50%] h-[40%] bg-primary/5 blur-[120px] rounded-full pointer-events-none -z-10"></div>
<div class="fixed bottom-[-5%] left-[-5%] w-[40%] h-[30%] bg-primary/5 blur-[100px] rounded-full pointer-events-none -z-10"></div>
</body></html>

```

---

## Screen 5 — Profile Setup Screen

**File:** `ProfileSetupView.swift`

**Purpose:** Collect basic profile info after auth. Shown only on first sign-in.

**UI Components:**
- Title: "Set up your profile"
- Circular profile photo picker with camera badge (tappable)
- Full Name text field (pre-filled from Google/Apple if available)
- UC Davis Email field (pre-filled if from Google, must end in @ucdavis.edu)
- Year picker: Freshman / Sophomore / Junior / Senior / Grad
- "Let's Go" primary button (full width)
- "Skip for now" text link below

**Logic:**
- On "Let's Go" → save profile to UserDefaults (and backend if available)
- Set `AppState.shared.isAuthenticated = true`
- Dismiss onboarding → ContentView appears
- "Skip for now" → same result, just with empty profile fields

**Design Reference (paste Stitch CSS/code below):**

```
/* PASTE SCREEN 5 STITCH CODE HERE */

<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "primary": "#00d0ff",
                        "background-light": "#f5f8f8",
                        "background-dark": "#0f1f23",
                    },
                    fontFamily: {
                        "display": ["Plus Jakarta Sans"]
                    },
                    borderRadius: {"DEFAULT": "1rem", "lg": "2rem", "xl": "3rem", "full": "9999px"},
                },
            },
        }
    </script>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background-light dark:bg-background-dark font-display text-slate-900 dark:text-slate-100 min-h-screen flex flex-col items-center justify-start">
<div class="relative flex h-full min-h-screen w-full max-w-md flex-col bg-background-light dark:bg-background-dark overflow-x-hidden">
<!-- Header Navigation -->
<div class="flex items-center p-4 justify-between">
<button class="text-slate-900 dark:text-slate-100 flex size-12 shrink-0 items-center justify-center rounded-full hover:bg-slate-200 dark:hover:bg-slate-800 transition-colors">
<span class="material-symbols-outlined">arrow_back</span>
</button>
<h2 class="text-lg font-bold leading-tight tracking-tight flex-1 text-center pr-12">Profile Setup</h2>
</div>
<!-- Hero Section -->
<div class="flex p-6 flex-col items-center gap-6">
<div class="relative">
<div class="bg-center bg-no-repeat aspect-square bg-cover rounded-full min-h-32 w-32 border-4 border-primary/20 bg-slate-200 dark:bg-slate-800 flex items-center justify-center overflow-hidden" data-alt="Abstract student avatar placeholder with blue gradient" style="background-image: linear-gradient(135deg, #00d0ff20 0%, #00d0ff40 100%);">
<span class="material-symbols-outlined text-4xl text-primary/40">person</span>
</div>
<button class="absolute bottom-0 right-0 bg-primary text-background-dark p-2 rounded-full border-4 border-background-light dark:border-background-dark shadow-lg hover:scale-105 transition-transform">
<span class="material-symbols-outlined text-base">photo_camera</span>
</button>
</div>
<div class="flex flex-col items-center justify-center gap-1">
<h1 class="text-2xl font-bold leading-tight tracking-tight text-center">Set up your profile</h1>
<p class="text-slate-500 dark:text-slate-400 text-base font-normal text-center">Tell us a bit about yourself</p>
</div>
</div>
<!-- Form Inputs -->
<div class="flex flex-col gap-5 px-6 py-2">
<label class="flex flex-col gap-2">
<span class="text-sm font-semibold text-slate-700 dark:text-slate-300 ml-1">Full Name</span>
<input class="form-input flex w-full rounded-xl text-slate-900 dark:text-white border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 focus:border-primary focus:ring-2 focus:ring-primary/20 h-14 px-4 text-base transition-all" placeholder="Enter your name" type="text" value="Gunrock Aggie"/>
</label>
<label class="flex flex-col gap-2">
<span class="text-sm font-semibold text-slate-700 dark:text-slate-300 ml-1">UC Davis Email</span>
<input class="form-input flex w-full rounded-xl text-slate-900 dark:text-white border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 focus:border-primary focus:ring-2 focus:ring-primary/20 h-14 px-4 text-base transition-all" placeholder="email@ucdavis.edu" type="email" value="gunrock@ucdavis.edu"/>
</label>
</div>
<!-- Year Selector -->
<div class="px-6 py-6 flex flex-col gap-3">
<span class="text-sm font-semibold text-slate-700 dark:text-slate-300 ml-1">Year</span>
<div class="flex flex-wrap gap-2">
<button class="px-4 py-2 rounded-full border border-primary bg-primary/10 text-primary text-sm font-medium transition-colors">
                    Freshman
                </button>
<button class="px-4 py-2 rounded-full border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 text-slate-600 dark:text-slate-400 text-sm font-medium hover:border-primary/50 transition-colors">
                    Sophomore
                </button>
<button class="px-4 py-2 rounded-full border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 text-slate-600 dark:text-slate-400 text-sm font-medium hover:border-primary/50 transition-colors">
                    Junior
                </button>
<button class="px-4 py-2 rounded-full border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 text-slate-600 dark:text-slate-400 text-sm font-medium hover:border-primary/50 transition-colors">
                    Senior
                </button>
<button class="px-4 py-2 rounded-full border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900/50 text-slate-600 dark:text-slate-400 text-sm font-medium hover:border-primary/50 transition-colors">
                    Grad
                </button>
</div>
</div>
<!-- Bottom Actions -->
<div class="mt-auto p-6 flex flex-col items-center gap-4">
<button class="w-full h-14 bg-primary hover:bg-primary/90 text-background-dark font-bold text-lg rounded-full shadow-[0_8px_20px_-4px_rgba(0,208,255,0.4)] transition-all active:scale-[0.98]">
                Let's Go
            </button>
<button class="text-slate-500 dark:text-slate-400 text-sm font-medium hover:text-primary transition-colors py-2">
                Skip for now
            </button>
</div>
<!-- Safe area spacer for mobile -->
<div class="h-4 bg-transparent"></div>
</div>
</body></html>
```

---

## OnboardingViewModel

**File:** `OnboardingViewModel.swift`

**Responsibilities:**
- Track current onboarding step
- Hold user input state (phone number, OTP, name, email, year)
- Handle all three auth flows (Apple, Google, Phone)
- On success, call `AppState.shared.isAuthenticated = true`

```swift
// Scaffold — fill in auth logic

@Observable
class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var phoneNumber: String = ""
    var otpCode: String = ""
    var displayName: String = ""
    var email: String = ""
    var year: String = "Freshman"
    var isLoading: Bool = false
    var errorMessage: String? = nil

    enum OnboardingStep {
        case welcome
        case signInOptions
        case phoneEntry
        case otpVerification
        case profileSetup
    }

    func signInWithApple() async { /* implement */ }
    func signInWithGoogle() async { /* implement */ }
    func sendOTP() async { /* implement */ }
    func verifyOTP() async { /* implement */ }
    func completeProfile() { /* implement */ }
}
```

---

## App Entry Point Gate

**File:** `TapInAppApp.swift` — update to show onboarding on first launch:

```swift
@main
struct TapInAppApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
```

---

## Implementation Notes

- Use `@AppStorage("isAuthenticated")` or `UserDefaults` to persist login state
- Google Sign-In requires adding the GoogleSignIn SDK via SPM and a `GoogleService-Info.plist`
- Apple Sign-In requires enabling the "Sign in with Apple" capability in Xcode → Signing & Capabilities
- Phone OTP requires either Firebase Auth (recommended) or a Twilio backend
- All transitions between onboarding steps should use smooth SwiftUI animations (`.transition(.move(edge: .trailing))`)
- The onboarding should NOT be shown again after the user completes it, even after app restarts

---

## Dependencies to Add (SPM)

| Service | Package |
|---------|---------|
| Google Sign-In | `https://github.com/google/GoogleSignIn-iOS` |
| Firebase Auth (for Phone OTP) | `https://github.com/firebase/firebase-ios-sdk` |

Apple Sign-In is native — no package needed.

<!DOCTYPE html>
<html class="light" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>UC Davis News Home Refined Nav</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Work+Sans:wght@300;400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "primary": "#022851",
                        "accent-gold": "#FFBF00",
                        "background-light": "#f5f7f8",
                        "background-dark": "#0f1923",
                    },
                    fontFamily: {
                        "display": ["Work Sans", "sans-serif"]
                    },
                    borderRadius: {
                        "DEFAULT": "0.25rem",
                        "lg": "0.5rem",
                        "xl": "0.75rem",
                        "full": "9999px"
                    },
                },
            },
        }
    </script>
<style type="text/tailwindcss">
        body {
            font-family: 'Work Sans', sans-serif;
            -webkit-tap-highlight-color: transparent;
        }
        .ios-blur {
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
        }
        .no-scrollbar::-webkit-scrollbar {
            display: none;
        }
        .no-scrollbar {
            -ms-overflow-style: none;
            scrollbar-width: none;
        }
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
        .fill-1 {
            font-variation-settings: 'FILL' 1;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background-light dark:bg-background-dark text-slate-900 dark:text-slate-100 font-display min-h-[100dvh]">
<header class="sticky top-0 z-50 bg-white/80 dark:bg-background-dark/80 ios-blur border-b border-slate-200 dark:border-slate-800">
<div class="flex items-center gap-3 px-4 h-16">
<div class="bg-primary p-1.5 rounded-lg shrink-0 shadow-sm">
<span class="material-symbols-outlined text-white text-xl block">school</span>
</div>
<div class="flex-1 relative">
<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[20px]">search</span>
<input class="w-full bg-slate-100 dark:bg-slate-800 border-none rounded-full py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/10 transition-all placeholder:text-slate-400 dark:placeholder:text-slate-500" placeholder="Search UC Davis News" type="text"/>
</div>
<button class="p-2 text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-full transition-colors">
<span class="material-symbols-outlined text-[24px]">settings</span>
</button>
</div>
</header>
<main class="pb-32">
<div class="flex gap-3 px-4 py-4 overflow-x-auto no-scrollbar items-center">
<div class="flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-full bg-primary px-5 text-white shadow-md">
<span class="text-sm font-semibold tracking-wide">Top Stories</span>
</div>
<div class="flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-4 text-slate-700 dark:text-slate-300">
<span class="material-symbols-outlined text-lg">science</span>
<span class="text-sm font-medium">Research</span>
</div>
<div class="flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-4 text-slate-700 dark:text-slate-300">
<span class="material-symbols-outlined text-lg">apartment</span>
<span class="text-sm font-medium">Campus</span>
</div>
<div class="flex h-9 shrink-0 items-center justify-center gap-x-2 rounded-full bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-4 text-slate-700 dark:text-slate-300">
<span class="material-symbols-outlined text-lg">sports_football</span>
<span class="text-sm font-medium">Athletics</span>
</div>
</div>
<div class="px-4 mb-6">
<div class="bg-gradient-to-br from-primary via-blue-900 to-primary rounded-2xl p-5 flex items-center justify-between shadow-xl shadow-primary/20 relative overflow-hidden">
<div class="absolute -right-4 -top-4 opacity-10">
<span class="material-symbols-outlined text-[120px]">extension</span>
</div>
<div class="flex items-center gap-4 relative z-10">
<div class="w-14 h-14 bg-accent-gold rounded-xl flex items-center justify-center shadow-lg">
<span class="material-symbols-outlined text-primary text-3xl font-bold">extension</span>
</div>
<div>
<h3 class="text-white font-bold text-lg leading-tight">Aggie Puzzles</h3>
<p class="text-blue-200 text-xs">Test your campus knowledge</p>
</div>
</div>
<button class="bg-white text-primary px-5 py-2.5 rounded-full text-xs font-black shadow-lg active:scale-95 transition-transform relative z-10">
                PLAY NOW
            </button>
</div>
</div>
<div class="px-4 mb-6">
<div class="relative flex flex-col overflow-hidden rounded-2xl bg-white dark:bg-slate-900 shadow-lg border border-slate-100 dark:border-slate-800">
<div class="w-full aspect-[16/10] bg-center bg-cover" data-alt="Large high-tech solar panels on a grassy campus field" style="background-image: url('https://lh3.googleusercontent.com/aida-public/AB6AXuCtl3vg3uGMBYP9s0h9ffr41jpSikM3Zx299XXinx21axfpwtYomyU_z8CcmALt8HdQqiP33TmkmyibVjN-NQdzs_YXtbd9CS3n9PlYBfv8j4vhE12Haw1N3zzzIdoRNC9xDtnT7E3-47r8sLXzm1WMDQwjwIEzeT46qY7nznTs1KhtDOJDkKbNbY6VnE4nPFEqCVKlpp993H9_v8IxXuftibFEcMW1oaF8OKbOpSBc6oUBho1hKSAeiTCmYfVU--VdRJZ0wQ9_7Rs');">
<div class="absolute top-4 left-4 bg-accent-gold text-primary text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-widest shadow-sm">
                    Featured
                </div>
</div>
<div class="p-5">
<div class="flex items-center gap-2 mb-2">
<span class="text-primary dark:text-accent-gold text-xs font-bold uppercase tracking-widest">Research</span>
<span class="text-slate-400 dark:text-slate-500 text-xs">•</span>
<span class="text-slate-500 dark:text-slate-400 text-xs">2h ago</span>
</div>
<h2 class="text-primary dark:text-white text-2xl font-bold leading-tight mb-3">New Solar Research on West Campus Breakthrough</h2>
<p class="text-slate-600 dark:text-slate-400 text-sm leading-relaxed mb-5">
                    UC Davis researchers unveil a revolutionary solar panel design that increases efficiency by 20% in agricultural settings.
                </p>
<div class="flex items-center justify-between border-t border-slate-50 dark:border-slate-800 pt-4">
<div class="flex items-center gap-2">
<span class="text-slate-400 dark:text-slate-500 text-xs italic">By Dr. Elena Vance</span>
</div>
<button class="text-primary dark:text-accent-gold text-sm font-bold flex items-center gap-1">
                        Read More <span class="material-symbols-outlined text-lg">chevron_right</span>
</button>
</div>
</div>
</div>
</div>
<div class="px-4 mb-4 flex items-center justify-between">
<h3 class="text-slate-900 dark:text-white text-lg font-bold">Latest Updates</h3>
<button class="text-primary dark:text-accent-gold text-sm font-semibold">See all</button>
</div>
<div class="px-4 flex flex-col gap-4">
<div class="bg-white dark:bg-slate-900 rounded-2xl p-4 shadow-sm border border-slate-100 dark:border-slate-800 flex gap-4">
<div class="flex-1">
<p class="text-primary dark:text-accent-gold text-[10px] font-bold uppercase mb-1">Campus Life</p>
<h4 class="text-slate-900 dark:text-white text-base font-bold leading-snug mb-2">Picnic Day 2024 Schedule Announced</h4>
<p class="text-slate-400 text-[10px] mt-2 italic flex items-center gap-1">
<span class="material-symbols-outlined text-[14px]">schedule</span> 4h ago • 3 min read
                </p>
</div>
<div class="w-20 h-20 shrink-0 rounded-xl bg-center bg-cover" data-alt="Crowds of students celebrating at an outdoor festival" style="background-image: url('https://lh3.googleusercontent.com/aida-public/AB6AXuC-s9POIhL3a3F20ajHSkwzPjGnPKgVDADBJu7uLOET7aSU6w8JmRPi7_Yfx3irHznrPbIhTFWQTdy-8KmKV6_jsqscDu4v8mC5iMT7eIcBnC1Kj57Ezve7Cmvn90WUOwcKRaCAtz3p2GkURWUFwQ-_9VfncMo_PNHuQ9pfrtQuSJLCBosXuNznbmRg-FeR8lTd7-SjDEECd32zBRhwN0fYXfFUR2dHGj--aA_a95l_Crp68rA1DtXM_bYZKPTM46X9xvjd4Y72Ipk');">
</div>
</div>
<div class="bg-white dark:bg-slate-900 rounded-2xl p-4 shadow-sm border border-slate-100 dark:border-slate-800 flex gap-4">
<div class="flex-1">
<p class="text-primary dark:text-accent-gold text-[10px] font-bold uppercase mb-1">Athletics</p>
<h4 class="text-slate-900 dark:text-white text-base font-bold leading-snug mb-2">Aggies Win Big in Conference Finals</h4>
<p class="text-slate-400 text-[10px] mt-2 italic flex items-center gap-1">
<span class="material-symbols-outlined text-[14px]">schedule</span> 6h ago • 5 min read
                </p>
</div>
<div class="w-20 h-20 shrink-0 rounded-xl bg-center bg-cover" data-alt="Football players celebrating a touchdown on the field" style="background-image: url('https://lh3.googleusercontent.com/aida-public/AB6AXuD9z3fMcRZYFpFtjokaRq7Ggkku8VA-yaBy61zec4bDtMHM5clLuowJW0ZXHvtLE4TxfYcb5HZ4HllDpTAoj8zqs33tYlno_qA7aDmUO3bxeAUCFdTxXL_rUAm4i0bISCMnWl3aLcd5lj70qoCzNlrm6S-Q5EyCFzbq5nOJOEhxdCOypo4QhGRanSOCyPZ0rZJjSZ5KRh0wydJmHRoch6ghx5t79ZRqUev1VsE8vBdVUsC7-bQqcKr47snXaVNoTertSrmd3nFmlBg');">
</div>
</div>
</div>
</main>
<nav class="fixed bottom-0 left-0 right-0 bg-white/95 dark:bg-background-dark/95 border-t border-slate-200 dark:border-slate-800 pb-8 pt-2 ios-blur z-50">
<div class="flex justify-around items-end px-2 max-w-md mx-auto">
<a class="flex flex-col items-center gap-1 text-primary dark:text-accent-gold w-16" href="#">
<span class="material-symbols-outlined fill-1 text-[26px]">newspaper</span>
<span class="text-[10px] font-bold">News</span>
</a>
<a class="flex flex-col items-center gap-1 text-slate-400 dark:text-slate-500 w-16" href="#">
<span class="material-symbols-outlined text-[26px]">apartment</span>
<span class="text-[10px] font-semibold">Campus</span>
</a>
<a class="flex flex-col items-center gap-1 w-16" href="#">
<div class="bg-accent-gold text-primary p-2.5 rounded-2xl shadow-md -mb-1 transform active:scale-90 transition-all">
<span class="material-symbols-outlined text-[28px] font-bold block">extension</span>
</div>
<span class="text-[10px] font-bold text-primary dark:text-accent-gold">Games</span>
</a>
<a class="flex flex-col items-center gap-1 text-slate-400 dark:text-slate-500 w-16" href="#">
<span class="material-symbols-outlined text-[26px]">bookmark</span>
<span class="text-[10px] font-semibold">Saved</span>
</a>
<a class="flex flex-col items-center gap-1 text-slate-400 dark:text-slate-500 w-16" href="#">
<span class="material-symbols-outlined text-[26px]">account_circle</span>
<span class="text-[10px] font-semibold">Profile</span>
</a>
</div>
<div class="h-1.5 w-32 bg-slate-200 dark:bg-slate-800 mx-auto mt-4 rounded-full"></div>
</nav>

</body></html>

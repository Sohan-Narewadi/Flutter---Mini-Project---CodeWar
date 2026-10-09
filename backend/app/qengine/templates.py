"""Free, offline problem generator.

Each Template is a parameterized problem: the statement is fixed, but
constants (`@K@` tokens) and the test inputs are randomized, so repeated
requests produce different instances. Reference solutions are plain Python;
expected outputs are computed from them by the judge (see verify.py).
"""
import random
from dataclasses import dataclass
from typing import Callable

from app.qengine.types import GeneratedQuestion

TOPICS = ["arrays", "strings", "math", "hashmap", "two-pointers", "dp"]
TOPIC_LABELS = {
    "arrays": "Arrays", "strings": "Strings", "math": "Math", "hashmap": "Hash Maps",
    "two-pointers": "Two Pointers", "dp": "Dynamic Programming",
}
DIFFICULTIES = ("easy", "medium", "hard")

_WORDS = ["code", "war", "array", "stack", "queue", "graph", "tree", "heap", "loop", "bug",
          "byte", "node", "hash", "sort", "merge", "scan", "ping", "lock"]
_ANAGRAM_BASES = ["listen", "stone", "night", "angel", "evil", "race", "post", "tea"]


@dataclass(frozen=True)
class Template:
    topic: str
    difficulty: str
    title: str
    fn: str                     # python entry point (snake_case)
    params: tuple
    prompt: str
    ref: str
    gen: Callable               # (rng, consts) -> list of argument lists
    consts: Callable | None = None   # (rng) -> {"K": 3}


def _ints(rng, n, lo, hi):
    return [rng.randint(lo, hi) for _ in range(n)]


def _fill(rng, edge, make, total=6):
    cases = [list(e) for e in edge]
    while len(cases) < total:
        cases.append(make())
    return cases


def _letters(rng, n, alphabet="abcdefghij"):
    return "".join(rng.choice(alphabet) for _ in range(n))


def _camel(snake: str) -> str:
    head, *rest = snake.split("_")
    return head + "".join(p.title() for p in rest)


def _apply(text: str, consts: dict) -> str:
    for k, v in consts.items():
        text = text.replace(f"@{k}@", str(v))
    return text


# --- generators ----------------------------------------------------------

def _g_sum_evens(rng, c):
    return _fill(rng, [[[]], [[1, 3, 5]], [[2, -4, 6]]], lambda: [_ints(rng, rng.randint(1, 10), -20, 20)])


def _g_second_largest(rng, c):
    def make():
        base = rng.sample(range(-20, 40), rng.randint(2, 6))
        arr = base + [rng.choice(base) for _ in range(rng.randint(0, 3))]
        rng.shuffle(arr)
        return [arr]
    return _fill(rng, [[[3, 1, 4, 1, 5]], [[9, 9, 8]]], make)


def _g_rotate(rng, c):
    return _fill(rng, [[[1, 2, 3, 4, 5], 2], [[7], 3]],
                 lambda: [_ints(rng, rng.randint(1, 8), -9, 30), rng.randint(0, 15)])


def _g_max_subarray(rng, c):
    return _fill(rng, [[[-3, -1, -2]], [[-2, 1, -3, 4, -1, 2, 1, -5, 4]]],
                 lambda: [_ints(rng, rng.randint(1, 9), -10, 10)])


def _g_product_except(rng, c):
    return _fill(rng, [[[1, 2, 3, 4]], [[2, 0, 3]]], lambda: [_ints(rng, rng.randint(2, 6), -4, 5)])


def _g_pairs_diff(rng, c):
    return _fill(rng, [[[1, 2, 3, 4, 5]]], lambda: [_ints(rng, rng.randint(2, 10), 0, 12)])


def _g_vowels(rng, c):
    return _fill(rng, [[""], ["rhythm"], ["Education"]],
                 lambda: [_letters(rng, rng.randint(1, 12), "abcdeiouxyz ABCDE")])


def _g_reverse_words(rng, c):
    def make():
        words = [rng.choice(_WORDS) for _ in range(rng.randint(1, 6))]
        return [("  " if rng.random() < 0.3 else " ").join(words)]
    return _fill(rng, [["hello world"], ["single"]], make)


def _g_palindrome(rng, c):
    def make():
        if rng.random() < 0.5:
            half = _letters(rng, rng.randint(1, 5), "abcdXYZ12")
            mid = rng.choice(["", "q", ", "])
            return [half + mid + half[::-1].swapcase()]
        return [_letters(rng, rng.randint(2, 8), "abcd")]
    return _fill(rng, [["A man, a plan, a canal: Panama"], ["race a car"], [""]], make)


def _g_longest_run(rng, c):
    return _fill(rng, [["aaabb"], [""], ["abc"]], lambda: [_letters(rng, rng.randint(1, 12), "abc")])


def _g_caesar(rng, c):
    return _fill(rng, [["xyz abc"], ["Hello, World 42"]],
                 lambda: [_letters(rng, rng.randint(1, 10), "abcxyzmnop ABC12")])


def _g_longest_unique(rng, c):
    return _fill(rng, [["abcabcbb"], ["bbbbb"], ["pwwkew"]], lambda: [_letters(rng, rng.randint(0, 12), "abcde")])


def _g_digit_sum(rng, c):
    return _fill(rng, [[0], [9], [12345]], lambda: [rng.randint(0, 10**9)])


def _g_multiples(rng, c):
    return _fill(rng, [[0], [c["K"] * 3]], lambda: [rng.randint(0, 1000)])


def _g_is_prime(rng, c):
    return _fill(rng, [[1], [2], [97], [100]], lambda: [rng.randint(0, 10000)])


def _g_gcd_list(rng, c):
    def make():
        base = rng.randint(1, 9)
        return [[base * rng.randint(1, 12) for _ in range(rng.randint(2, 6))]]
    return _fill(rng, [[[12, 18, 24]], [[7, 13]]], make)


def _g_count_primes(rng, c):
    return _fill(rng, [[0], [2], [10], [100]], lambda: [rng.randint(0, 2000)])


def _g_fib_mod(rng, c):
    return _fill(rng, [[0], [1], [10]], lambda: [rng.randint(0, 60)])


def _g_has_duplicate(rng, c):
    def make():
        if rng.random() < 0.5:
            arr = rng.sample(range(0, 40), rng.randint(1, 8))
        else:
            arr = rng.sample(range(0, 40), rng.randint(1, 8))
            arr.append(rng.choice(arr))
            rng.shuffle(arr)
        return [arr]
    return _fill(rng, [[[1, 2, 3, 1]], [[1, 2, 3]]], make)


def _g_first_unique(rng, c):
    return _fill(rng, [["aabb"], ["leetcode"], ["loveleetcode"]], lambda: [_letters(rng, rng.randint(1, 10), "aabbcde")])


def _g_two_sum(rng, c):
    def make():
        for _ in range(60):
            arr = rng.sample(range(-30, 60), rng.randint(3, 8))
            i, j = sorted(rng.sample(range(len(arr)), 2))
            target = arr[i] + arr[j]
            pairs = sum(1 for a in range(len(arr)) for b in range(a + 1, len(arr)) if arr[a] + arr[b] == target)
            if pairs == 1:
                return [arr, target]
        return [[2, 7, 11, 15], 9]
    return _fill(rng, [[[2, 7, 11, 15], 9]], make)


def _g_anagram_groups(rng, c):
    def make():
        words = []
        for base in rng.sample(_ANAGRAM_BASES, rng.randint(2, 4)):
            for _ in range(rng.randint(1, 3)):
                letters = list(base)
                rng.shuffle(letters)
                words.append("".join(letters))
        rng.shuffle(words)
        return [words]
    return _fill(rng, [[["eat", "tea", "tan", "ate", "nat", "bat"]], [[]]], make)


def _g_longest_consecutive(rng, c):
    return _fill(rng, [[[100, 4, 200, 1, 3, 2]], [[]]], lambda: [_ints(rng, rng.randint(0, 10), 0, 20)])


def _g_reverse_array(rng, c):
    return _fill(rng, [[[]], [[1, 2, 3]]], lambda: [_ints(rng, rng.randint(1, 9), -20, 20)])


def _g_sorted_pair(rng, c):
    def make():
        arr = sorted(_ints(rng, rng.randint(2, 8), -10, 20))
        if rng.random() < 0.5:
            i, j = sorted(rng.sample(range(len(arr)), 2))
            return [arr, arr[i] + arr[j]]
        return [arr, rng.randint(-25, 45)]
    return _fill(rng, [[[1, 2, 3, 4], 5], [[1, 2, 3, 4], 100]], make)


def _g_max_area(rng, c):
    return _fill(rng, [[[1, 8, 6, 2, 5, 4, 8, 3, 7]], [[1, 1]]], lambda: [_ints(rng, rng.randint(2, 9), 1, 15)])


def _g_triplets(rng, c):
    return _fill(rng, [[[0, 0, 0]], [[1, 2, 3]], [[-1, 0, 1, 2, -1, -4]]], lambda: [_ints(rng, rng.randint(3, 9), -5, 5)])


def _g_distinct_sorted(rng, c):
    return _fill(rng, [[[]], [[1, 1, 2]]], lambda: [sorted(_ints(rng, rng.randint(1, 10), 0, 6))])


def _g_stairs(rng, c):
    return _fill(rng, [[1], [2], [5]], lambda: [rng.randint(1, 30)])


def _g_rob(rng, c):
    return _fill(rng, [[[]], [[2, 7, 9, 3, 1]]], lambda: [_ints(rng, rng.randint(0, 9), 0, 30)])


def _g_coins(rng, c):
    def make():
        coins = rng.sample([1, 2, 3, 5, 10, 25], rng.randint(1, 4))
        return [coins, rng.randint(0, 40)]
    return _fill(rng, [[[1, 2, 5], 11], [[2], 3]], make)


def _g_lis(rng, c):
    return _fill(rng, [[[]], [[10, 9, 2, 5, 3, 7, 101, 18]]], lambda: [_ints(rng, rng.randint(0, 9), 0, 20)])


def _g_edit(rng, c):
    return _fill(rng, [["kitten", "sitting"], ["", "abc"]],
                 lambda: [_letters(rng, rng.randint(0, 6), "abc"), _letters(rng, rng.randint(0, 6), "abc")])


def _g_grid(rng, c):
    def make():
        r, cc = rng.randint(1, 5), rng.randint(1, 5)
        grid = [[1 if rng.random() < 0.2 else 0 for _ in range(cc)] for _ in range(r)]
        grid[0][0] = 0
        grid[r - 1][cc - 1] = 0
        return [grid]
    return _fill(rng, [[[[0, 0, 0], [0, 1, 0], [0, 0, 0]]], [[[0, 1], [0, 0]]], [[[1]]]], make)


def _k(lo, hi):
    return lambda rng: {"K": rng.randint(lo, hi)}


TEMPLATES: list[Template] = [
    # --- arrays
    Template("arrays", "easy", "Sum of Evens", "sum_of_evens", ("nums",),
             "Given a list of integers `nums`, return the sum of all even numbers (0 if there are none).",
             "def sum_of_evens(nums):\n    return sum(x for x in nums if x % 2 == 0)\n", _g_sum_evens),
    Template("arrays", "easy", "Second Largest", "second_largest", ("nums",),
             "Return the second largest distinct value in `nums`. The list always contains at least two distinct values.",
             "def second_largest(nums):\n    return sorted(set(nums))[-2]\n", _g_second_largest),
    Template("arrays", "medium", "Rotate Right", "rotate_right", ("nums", "k"),
             "Rotate `nums` to the right by `k` steps (k may be larger than the length) and return the new list.",
             "def rotate_right(nums, k):\n    if not nums:\n        return []\n    k %= len(nums)\n"
             "    return nums[-k:] + nums[:-k] if k else list(nums)\n", _g_rotate),
    Template("arrays", "medium", "Maximum Subarray", "max_subarray", ("nums",),
             "Return the largest sum of any non-empty contiguous subarray of `nums`.",
             "def max_subarray(nums):\n    best = cur = nums[0]\n    for x in nums[1:]:\n"
             "        cur = max(x, cur + x)\n        best = max(best, cur)\n    return best\n", _g_max_subarray),
    Template("arrays", "medium", "Pairs With Difference @K@", "count_pairs_diff", ("nums",),
             "Count the pairs of positions i < j where the absolute difference |nums[i] - nums[j]| equals @K@.",
             "def count_pairs_diff(nums):\n    n = len(nums)\n    return sum(1 for i in range(n) for j in range(i + 1, n) if abs(nums[i] - nums[j]) == @K@)\n",
             _g_pairs_diff, _k(1, 5)),
    Template("arrays", "hard", "Product Except Self", "product_except_self", ("nums",),
             "Return a list where element i is the product of every element of `nums` except `nums[i]`. Aim for O(n) without division.",
             "def product_except_self(nums):\n    n = len(nums)\n    res = [1] * n\n    p = 1\n    for i in range(n):\n"
             "        res[i] = p\n        p *= nums[i]\n    p = 1\n    for i in range(n - 1, -1, -1):\n"
             "        res[i] *= p\n        p *= nums[i]\n    return res\n", _g_product_except),
    # --- strings
    Template("strings", "easy", "Count Vowels", "count_vowels", ("s",),
             "Return how many vowels (a, e, i, o, u, case-insensitive) appear in `s`.",
             "def count_vowels(s):\n    return sum(1 for c in s.lower() if c in 'aeiou')\n", _g_vowels),
    Template("strings", "easy", "Reverse Words", "reverse_words", ("s",),
             "Words in `s` are separated by one or more spaces. Return the words in reverse order, joined by single spaces.",
             "def reverse_words(s):\n    return ' '.join(reversed(s.split()))\n", _g_reverse_words),
    Template("strings", "medium", "Clean Palindrome", "is_palindrome", ("s",),
             "Return True if `s` reads the same forwards and backwards when only letters and digits are considered and case is ignored.",
             "def is_palindrome(s):\n    t = [c.lower() for c in s if c.isalnum()]\n    return t == t[::-1]\n", _g_palindrome),
    Template("strings", "medium", "Longest Run", "longest_run", ("s",),
             "Return the length of the longest run of identical consecutive characters in `s` (0 for an empty string).",
             "def longest_run(s):\n    best = cur = 0\n    prev = None\n    for ch in s:\n"
             "        cur = cur + 1 if ch == prev else 1\n        prev = ch\n        best = max(best, cur)\n    return best\n",
             _g_longest_run),
    Template("strings", "medium", "Caesar Shift @K@", "caesar", ("s",),
             "Shift every lowercase letter in `s` forward by @K@ places in the alphabet (wrapping z to a). Leave every other character unchanged.",
             "def caesar(s):\n    out = []\n    for c in s:\n        if 'a' <= c <= 'z':\n"
             "            out.append(chr((ord(c) - 97 + @K@) % 26 + 97))\n        else:\n            out.append(c)\n"
             "    return ''.join(out)\n", _g_caesar, _k(1, 25)),
    Template("strings", "hard", "Longest Unique Substring", "longest_unique", ("s",),
             "Return the length of the longest substring of `s` that contains no repeated character.",
             "def longest_unique(s):\n    seen = {}\n    start = best = 0\n    for i, ch in enumerate(s):\n"
             "        if ch in seen and seen[ch] >= start:\n            start = seen[ch] + 1\n"
             "        seen[ch] = i\n        best = max(best, i - start + 1)\n    return best\n", _g_longest_unique),
    # --- math
    Template("math", "easy", "Sum of Digits", "digit_sum", ("n",),
             "Return the sum of the decimal digits of the non-negative integer `n`.",
             "def digit_sum(n):\n    return sum(int(c) for c in str(n))\n", _g_digit_sum),
    Template("math", "easy", "Multiples of @K@", "count_multiples", ("n",),
             "How many positive integers up to and including `n` are multiples of @K@?",
             "def count_multiples(n):\n    return n // @K@\n", _g_multiples, _k(2, 9)),
    Template("math", "medium", "Is Prime", "is_prime", ("n",),
             "Return True if `n` is a prime number, otherwise False. (0 and 1 are not prime.)",
             "def is_prime(n):\n    if n < 2:\n        return False\n    i = 2\n    while i * i <= n:\n"
             "        if n % i == 0:\n            return False\n        i += 1\n    return True\n", _g_is_prime),
    Template("math", "medium", "GCD of a List", "gcd_list", ("nums",),
             "Return the greatest common divisor of all the positive integers in `nums`.",
             "import math\n\ndef gcd_list(nums):\n    g = 0\n    for x in nums:\n        g = math.gcd(g, x)\n    return g\n",
             _g_gcd_list),
    Template("math", "medium", "Fibonacci Mod", "fib_mod", ("n",),
             "Return the n-th Fibonacci number (fib(0) = 0, fib(1) = 1) modulo 1000007.",
             "def fib_mod(n):\n    a, b = 0, 1\n    for _ in range(n):\n        a, b = b, (a + b) % 1000007\n    return a % 1000007\n",
             _g_fib_mod),
    Template("math", "hard", "Count Primes", "count_primes", ("n",),
             "Return the number of prime numbers strictly less than `n`.",
             "def count_primes(n):\n    if n < 3:\n        return 0\n    sieve = [True] * n\n    sieve[0] = sieve[1] = False\n"
             "    for i in range(2, int(n ** 0.5) + 1):\n        if sieve[i]:\n            for j in range(i * i, n, i):\n"
             "                sieve[j] = False\n    return sum(sieve)\n", _g_count_primes),
    # --- hash maps
    Template("hashmap", "easy", "Has Duplicate", "has_duplicate", ("nums",),
             "Return True if any value appears at least twice in `nums`.",
             "def has_duplicate(nums):\n    return len(set(nums)) != len(nums)\n", _g_has_duplicate),
    Template("hashmap", "easy", "First Unique Character", "first_unique_index", ("s",),
             "Return the index of the first character in `s` that appears exactly once, or -1 if there is none.",
             "def first_unique_index(s):\n    from collections import Counter\n    counts = Counter(s)\n"
             "    for i, ch in enumerate(s):\n        if counts[ch] == 1:\n            return i\n    return -1\n",
             _g_first_unique),
    Template("hashmap", "medium", "Two Sum", "two_sum", ("nums", "target"),
             "Exactly one pair of positions i < j satisfies nums[i] + nums[j] == target. Return [i, j].",
             "def two_sum(nums, target):\n    seen = {}\n    for j, x in enumerate(nums):\n"
             "        if target - x in seen:\n            return [seen[target - x], j]\n        seen[x] = j\n    return []\n",
             _g_two_sum),
    Template("hashmap", "medium", "Anagram Groups", "count_anagram_groups", ("words",),
             "Return how many distinct groups of mutual anagrams exist in the list `words`.",
             "def count_anagram_groups(words):\n    return len({''.join(sorted(w)) for w in words})\n", _g_anagram_groups),
    Template("hashmap", "hard", "Longest Consecutive Run", "longest_consecutive", ("nums",),
             "Return the length of the longest sequence of consecutive integers (like 3, 4, 5) that can be formed from the values in `nums`. Aim for O(n).",
             "def longest_consecutive(nums):\n    s = set(nums)\n    best = 0\n    for x in s:\n        if x - 1 not in s:\n"
             "            y = x\n            while y + 1 in s:\n                y += 1\n            best = max(best, y - x + 1)\n"
             "    return best\n", _g_longest_consecutive),
    # --- two pointers
    Template("two-pointers", "easy", "Reverse Array", "reverse_array", ("nums",),
             "Return a new list with the elements of `nums` in reverse order. Try it with two pointers.",
             "def reverse_array(nums):\n    res = list(nums)\n    i, j = 0, len(res) - 1\n    while i < j:\n"
             "        res[i], res[j] = res[j], res[i]\n        i += 1\n        j -= 1\n    return res\n", _g_reverse_array),
    Template("two-pointers", "easy", "Count Distinct (Sorted)", "count_distinct_sorted", ("nums",),
             "`nums` is sorted in ascending order. Return how many distinct values it contains.",
             "def count_distinct_sorted(nums):\n    count = 0\n    prev = None\n    for x in nums:\n"
             "        if prev is None or x != prev:\n            count += 1\n        prev = x\n    return count\n",
             _g_distinct_sorted),
    Template("two-pointers", "medium", "Sorted Pair Sum", "sorted_pair_sum", ("nums", "target"),
             "`nums` is sorted ascending. Return True if two different positions hold values that add up to `target`.",
             "def sorted_pair_sum(nums, target):\n    i, j = 0, len(nums) - 1\n    while i < j:\n        s = nums[i] + nums[j]\n"
             "        if s == target:\n            return True\n        if s < target:\n            i += 1\n        else:\n"
             "            j -= 1\n    return False\n", _g_sorted_pair),
    Template("two-pointers", "medium", "Container With Most Water", "max_area", ("heights",),
             "Each `heights[i]` is a vertical line at x = i. Return the largest water area (width x shorter line) formed by any two lines.",
             "def max_area(heights):\n    i, j = 0, len(heights) - 1\n    best = 0\n    while i < j:\n"
             "        best = max(best, (j - i) * min(heights[i], heights[j]))\n        if heights[i] < heights[j]:\n"
             "            i += 1\n        else:\n            j -= 1\n    return best\n", _g_max_area),
    Template("two-pointers", "hard", "Zero-Sum Triplets", "count_triplets_zero", ("nums",),
             "Return the number of unique triplets of values (a, b, c) taken from different positions of `nums` that sum to zero. Triplets with the same values count once.",
             "def count_triplets_zero(nums):\n    nums = sorted(nums)\n    found = set()\n    for i in range(len(nums) - 2):\n"
             "        l, r = i + 1, len(nums) - 1\n        while l < r:\n            s = nums[i] + nums[l] + nums[r]\n"
             "            if s == 0:\n                found.add((nums[i], nums[l], nums[r]))\n                l += 1\n                r -= 1\n"
             "            elif s < 0:\n                l += 1\n            else:\n                r -= 1\n    return len(found)\n",
             _g_triplets),
    # --- dynamic programming
    Template("dp", "easy", "Climbing Stairs", "climb_stairs", ("n",),
             "You can climb 1 or 2 steps at a time. In how many distinct ways can you climb a staircase of `n` steps?",
             "def climb_stairs(n):\n    a, b = 1, 1\n    for _ in range(n - 1):\n        a, b = b, a + b\n    return b\n", _g_stairs),
    Template("dp", "medium", "House Robber", "rob", ("nums",),
             "`nums[i]` is the money in house i. You cannot rob two adjacent houses. Return the maximum you can rob.",
             "def rob(nums):\n    a = b = 0\n    for x in nums:\n        a, b = b, max(b, a + x)\n    return b\n", _g_rob),
    Template("dp", "medium", "Minimum Coins", "min_coins", ("coins", "amount"),
             "Given coin values `coins` (unlimited supply) and a target `amount`, return the fewest coins needed, or -1 if it is impossible.",
             "def min_coins(coins, amount):\n    INF = float('inf')\n    dp = [0] + [INF] * amount\n    for a in range(1, amount + 1):\n"
             "        for c in coins:\n            if c <= a and dp[a - c] + 1 < dp[a]:\n                dp[a] = dp[a - c] + 1\n"
             "    return -1 if dp[amount] == INF else dp[amount]\n", _g_coins),
    Template("dp", "medium", "Longest Increasing Subsequence", "lis_length", ("nums",),
             "Return the length of the longest strictly increasing subsequence of `nums` (0 for an empty list).",
             "def lis_length(nums):\n    dp = []\n    for i, x in enumerate(nums):\n"
             "        dp.append(1 + max([dp[j] for j in range(i) if nums[j] < x], default=0))\n    return max(dp, default=0)\n",
             _g_lis),
    Template("dp", "hard", "Edit Distance", "edit_distance", ("a", "b"),
             "Return the minimum number of single-character insertions, deletions or replacements needed to turn string `a` into string `b`.",
             "def edit_distance(a, b):\n    m, n = len(a), len(b)\n    dp = [[0] * (n + 1) for _ in range(m + 1)]\n"
             "    for i in range(m + 1):\n        dp[i][0] = i\n    for j in range(n + 1):\n        dp[0][j] = j\n"
             "    for i in range(1, m + 1):\n        for j in range(1, n + 1):\n"
             "            cost = 0 if a[i - 1] == b[j - 1] else 1\n"
             "            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)\n    return dp[m][n]\n",
             _g_edit),
    Template("dp", "hard", "Grid Paths With Obstacles", "paths_with_obstacles", ("grid",),
             "`grid` is a matrix of 0 (free) and 1 (blocked). Moving only right or down from the top-left to the bottom-right cell, return the number of distinct paths that avoid blocked cells.",
             "def paths_with_obstacles(grid):\n    r, c = len(grid), len(grid[0])\n    dp = [[0] * c for _ in range(r)]\n"
             "    for i in range(r):\n        for j in range(c):\n            if grid[i][j] == 1:\n                dp[i][j] = 0\n"
             "            elif i == 0 and j == 0:\n                dp[i][j] = 1\n            else:\n"
             "                dp[i][j] = (dp[i - 1][j] if i else 0) + (dp[i][j - 1] if j else 0)\n    return dp[r - 1][c - 1]\n",
             _g_grid),
]


def generate_from_template(
    rng: random.Random,
    difficulty: str | None = None,
    topic: str | None = None,
    template: Template | None = None,
) -> GeneratedQuestion:
    """Builds a fresh instance of a template (random constants and inputs)."""
    if template is None:
        pool = [t for t in TEMPLATES
                if (difficulty is None or t.difficulty == difficulty) and (topic is None or t.topic == topic)]
        if not pool:
            raise ValueError(f"No template for difficulty={difficulty!r}, topic={topic!r}")
        template = rng.choice(pool)
    consts = template.consts(rng) if template.consts else {}
    return GeneratedQuestion(
        title=_apply(template.title, consts),
        difficulty=template.difficulty,
        topic=template.topic,
        prompt=_apply(template.prompt, consts),
        params=list(template.params),
        entry_python=template.fn,
        entry_ts=_camel(template.fn),
        reference_solution=_apply(template.ref, consts),
        inputs=template.gen(rng, consts),
        source="template",
        tags=[TOPIC_LABELS[template.topic]],
    )

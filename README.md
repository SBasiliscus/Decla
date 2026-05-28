# Számtekercs (Helix Matrix) – Elixir Project Documentation

**Author:** András Szabó (GA9BCR)
**Email:** sbasiliscus@gmail.com

## 📌 Task Description
The goal of this project is to fill an `n*n` square board where some cells contain numbers between 1 and `m`. The missing numbers (also between 1 and `m`) must be placed according to the following rules:

* Each row and each column must contain each number from `1..m` exactly once. Consequently, there are exactly `n-m` zeros in each row and column.
* Along the winding (helix) path starting from the top-left corner, the numbers must follow the sequence `1,2,...m,1,2,...,m,...` in order, ignoring the zeros. This sequence repeats exactly `n` times.
* **Helix Traversal Order:** It moves from left to right along the first row, then top to bottom down the last column. After that, it goes right to left along the last row, and bottom to top up the first column, stopping at the 2nd row, 1st column. After traversing the outer rows and columns, the traversal recursively continues on the inner `(n-2)*(n-2)` board starting at row 2, column 2.

The program returns a list of all valid solutions for a puzzle, where each solution is a two-dimensional list. If a puzzle has no solution, the function returns an empty list.

## 🏗️ Core Logic and Architecture

The solution algorithm is based on the following logical steps:

* **Row and Column Constraints (Sudoku-like Validation):** The program assigns a unique prime number to each value from `1..m`. For each row and column, it stores two values: the product of the prime numbers corresponding to the numbers present, and the count of zeros placed so far.
* **Board Flattening:** The two-dimensional grid is flattened into a single list along the helix traversal path, creating a `{row, column} => index` mapping for fast lookups.
* **Segmentation:** The flattened board is split into segments based on the non-zero initial constraints.
* **Zero Distribution:** A recursive algorithm calculates the mandatory and possible distribution of zeros across the different segments.
* **Backtracking Search:** The program traverses the cells in the helix order, building a binary search tree. At any given cell, it can take two branches: placing a valid value or placing a zero, provided that the row/column and segment constraints allow it. If no conditions are met, the branch is pruned.
* **Solution Reconstruction:** The discovered, flattened solutions are converted back into the expected two-dimensional list format.

## ⚙️ Key Modules and Functions

* `helix`: The main coordinator method that initializes helper collections, splits the board into segments, and searches for valid solutions based on the calculated zero distributions.
* `prime_array_builder`: A recursive method based on the Sieve of Eratosthenes that generates the first `m` prime numbers.
* **Constraint Managers (`conditions_array_builder`, `update_conditions`, `check_conditions`):** These manage a `4*n` long array storing and updating the prime products and zero counts for rows and columns, verifying if a specific value can be legally placed.
* `field_list_and_map_builder`: Constructs the list containing the coordinates in helix traversal order and builds a Map for fast index lookups.
* `min_max_distribution` and `possible_zeros_distribution_recursive`: These methods are responsible for calculating the minimum required zeros per segment and recursively generating all valid zero distributions across segments.
* `helix_rec_builder`: The primary backtracking method. It iterates through the cells, collecting solutions into an accumulator using pattern matching to handle 4 distinct cases (existing zero constraint, existing non-zero constraint, placing a new value, or placing a new zero).
* `result_announcer`: Converts the final flattened list of solutions back into the requested list of lists format.

## 💡 Key Findings and Experiences

* Although the prime-number-based (product-based) validation was an interesting approach, testing revealed that it did not speed up execution and turned out to be an unnecessary overcomplication.
* The code was successfully tested against the provided test cases.

# Tennis Database (SQLite)

Group 8 submission for **Assignment 1** of *INFOMDW – Data Wrangling* (MSc Applied Data Science, Utrecht University).

The project designs a relational database for professional tennis, queries it with SQL, and then analyses it from Python.

## Contents

| Path | Description |
| --- | --- |
| [`tennis.sql`](tennis.sql) | Tasks 1 and 2. Schema (with keys and constraints), sample data, and five queries (join, aggregate, nested query, self join, set operation). |
| [`task_3.ipynb`](task_3.ipynb) | Task 3. Python notebook that queries the database, loads a string attribute into a pandas DataFrame (`df_sim`), and implements a hash function with a reported collision rate. |
| [`report/Report_Group8_Assignment1.pdf`](report/Report_Group8_Assignment1.pdf) | Written report covering design decisions and results. |

## Requirements

- SQLite 3 (`sqlite3` command-line tool)
- Python 3.10+ with `pandas` and `jupyter`

```bash
pip install pandas jupyter
```

## How to run

### 1. Build the database and run the queries (Tasks 1 and 2)

```bash
sqlite3 tennis_assignment.db
sqlite> .read tennis.sql
```

The script enables foreign keys, drops any old tables, rebuilds the schema, loads the data, and runs the five queries. It can be re-run safely.

### 2. Run the Python analysis (Task 3)

Keep `tennis_assignment.db` in the same folder as the notebook, then:

```bash
jupyter notebook task_3.ipynb
```

## Task 3 finding

The hash function sums character codes, so it ignores letter order. Names made of the same letters in a different order collide. In the notebook's test set, 3 of 6 similar names shared an index. See the report for the collision rate on the full data.

## Notes

- The generated `*.db` file is not committed. Rebuild it from `tennis.sql`.
- Course: INFOMDW, Period 1, 2026–27.

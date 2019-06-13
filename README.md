# cicminus

Playground implementation of the Calculus of (Co-)Inductive Constructions with
type-based termination/productivity.

## Running Inferences

Run `stack build` to build the project, then run

```bash
stack exec -- cicminus [-v <VERBOSITY>] <FILE>
```

to run inference on the given file. Verbosity levels are listed below, defaulting to 1.

| Verbosity | Effects (cumulative) |
| --------- | ------- |
|  1        | `check`s and explicit `print`s are printed, as well as errors. |
| 10        | Constraints and constrainted types are printed when fixpoints are defined. |
| 15        | All constraints and detailed recCheck logs are printed. |
| 20        | Fixpoint subexpression types are printed. |
| 30        | Case/Match subexpression types and unificaiton logs are printed. |
| 35        | `eval`s and all subexpression types are printed. |
| 40        | New constraints, new stage variables, Match normalization/unification, and others are printed.
| 50        | Case checking, pattern checking, and declarations are printed. |
| 70        | Scoping, weak head normalization, and conversion logs are printed. |
| 80        | Inductive type normalization is printed. |

# Design Document: Grover's Search Algorithm in Q#

> Phase 2, Week 3 — Design & Setup milestone  
> This document describes the design of a beginner-friendly Grover Search project implemented in Microsoft Q# and executed only on a local simulator.

## 1. Project Goal

The goal of this project is to implement **Grover's Search Algorithm** on small search spaces using Q#. The project focuses on a simulator-only implementation, without requiring access to real quantum hardware.

Grover's algorithm is a quantum search algorithm used to find a marked item in an unstructured search space. In classical search, finding one target item among `N` possibilities may require `O(N)` queries. Grover's algorithm reduces this to approximately `O(√N)` oracle queries. In this project, the search spaces are intentionally kept small so that the algorithm remains understandable and easy to test.

The implementation demonstrates the main components of Grover's algorithm: preparing a uniform superposition, marking a target state with an oracle, amplifying the marked state's probability with a diffusion operator, and measuring the final state.

## 2. Problem Definition

The project searches for a single marked item in small quantum registers. Two search-space sizes are used:

| Experiment Group | Number of Qubits | Search Space Size | Target Pattern | Target State | Target Value |
|---|---:|---:|---|---|---:|
| Experiment 1 | 2 | 4 states | `[true, true]` | `|11⟩` | 3 |
| Experiments 2–4 | 3 | 8 states | `[true, false, true]` | `|101⟩` | 5 |

For the 2-qubit case, the possible basis states are:

```text
|00⟩, |01⟩, |10⟩, |11⟩
```

The marked solution is `|11⟩`. For the 3-qubit case, the search space contains eight possible states, and the marked solution is `|101⟩`.

The target is represented in the code with a `Bool[]` pattern. For example, `[true, true]` corresponds to `|11⟩`, and `[true, false, true]` corresponds to `|101⟩`. This makes the oracle reusable instead of hard-coding only one target state.

## 3. Algorithm Overview

Grover's algorithm starts with all qubits initialized to the all-zero state:

$$
|0\ldots0\rangle
$$

A Hadamard gate is applied to each qubit to create a uniform superposition over all possible candidates:

$$
|s\rangle = \frac{1}{\sqrt{N}} \sum_{x=0}^{N-1} |x\rangle
$$

For the 2-qubit case, this becomes:

$$
|s\rangle = \frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)
$$

After this preparation step, each candidate has equal measurement probability. If no Grover iteration were applied, measuring the state would be equivalent to random guessing.

The oracle then marks the target state by flipping only its phase:

$$
|x_{target}\rangle \rightarrow -|x_{target}\rangle
$$

All other states remain unchanged:

$$
|x\rangle \rightarrow |x\rangle \quad \text{for } x \neq x_{target}
$$

This phase flip does not directly increase the probability of the target. Instead, it creates a phase difference that the diffusion operator can use.

The diffusion operator performs an inversion about the mean. Conceptually, it reflects the state vector about the uniform superposition state:

$$
D = 2|s\rangle\langle s| - I
$$

This reflection increases the amplitude of the marked state and decreases the amplitudes of the unmarked states. The pair `oracle → diffusion` forms one Grover iteration.

Finally, the qubits are measured in the computational basis. If the algorithm is implemented correctly and the number of iterations is chosen properly, the marked state should appear with a much higher probability than random guessing.

## 4. Planned Q# Operations

The implementation is organized into small Q# operations, each responsible for one part of the algorithm.

| Operation | Purpose |
|---|---|
| `PrepareUniform` | Applies `H` to every qubit and prepares an equal superposition over all basis states. |
| `MarkTarget` | Implements the oracle. It maps the selected target pattern to the all-ones state using `X` gates, applies a phase flip, and then uncomputes the mapping. |
| `ReflectAboutAllOnes` | Applies a multi-controlled `Z` operation to flip the phase of the `|1...1⟩` state. |
| `ReflectAboutUniform` | Implements the diffusion operator using `Adjoint PrepareUniform`, `X` gates, and `ReflectAboutAllOnes`. |
| `GroverSearch` | Runs the full algorithm: prepare superposition, apply `(oracle → diffusion)` for the selected number of iterations, then measure. |
| `CalculateOptimalIterations` | Computes the approximate optimal number of Grover iterations for a single marked item. |
| `RunExperiment` | Runs the algorithm many times and reports the success frequency. |
| `DebugGroverOnce` | Uses `DumpMachine()` to inspect intermediate state vectors during a single 2-qubit debug run. |

This organization keeps the implementation readable and mirrors the conceptual structure of Grover's algorithm.

## 5. Oracle Design

The oracle is implemented in the `MarkTarget` operation. The goal of the oracle is not to measure or reveal the target state. Its only job is to apply a negative phase to the marked state.

For example, in the 2-qubit case with target `|11⟩`, the oracle transforms:

$$
\frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)
$$

into:

$$
\frac{1}{2}(|00\rangle + |01\rangle + |10\rangle - |11\rangle)
$$

The probabilities do not change immediately after the oracle. Only the phase of the target state changes.

To support different target states, the code first uses `X` gates to map the desired `targetPattern` to the all-ones state `|1...1⟩`. Then `ReflectAboutAllOnes` applies a multi-controlled `Z` phase flip. Finally, the `within/apply` structure automatically reverses the temporary `X` gates.

This design avoids writing a separate oracle for every possible target state. The same oracle structure can mark `|11⟩`, `|101⟩`, or another bit pattern.

## 6. Diffusion Operator Design

The diffusion operator is implemented in `ReflectAboutUniform`. Its purpose is to amplify the amplitude of the marked state after the oracle has applied a phase flip.

The diffusion operator is based on the reflection:

$$
D = 2|s\rangle\langle s| - I
$$

where `|s⟩` is the uniform superposition state. In Q#, this reflection is implemented through a sequence of gates rather than by directly constructing the matrix.

The implemented structure is:

```text
Adjoint PrepareUniform
X on all qubits
ReflectAboutAllOnes
X on all qubits
PrepareUniform
```

In the code, the preparation and uncomputation steps are written with Q#'s `within/apply` pattern. This makes the implementation cleaner and reduces the risk of forgetting to undo temporary transformations.

## 7. Iteration Strategy

The number of Grover iterations is important. Too few iterations may not amplify the target enough. Too many iterations can overshoot the target direction and reduce the success probability again.

For a single marked item, the approximate optimal number of iterations is based on:

$$
\theta = \arcsin\left(\frac{1}{\sqrt{N}}\right)
$$

and:

$$
k \approx \frac{\pi}{4\theta} - \frac{1}{2}
$$

The implementation uses `CalculateOptimalIterations` to compute this value instead of choosing the iteration count manually.

For the selected experiments:

| Number of Qubits | Search Space Size | Iteration Choice | Expected Behavior |
|---:|---:|---:|---|
| 2 | 4 | 1 | Near-perfect success for `|11⟩`. |
| 3 | 8 | 2 | High success probability for `|101⟩`. |
| 3 | 8 | 1 | Lower success because the target is not fully amplified. |
| 3 | 8 | 3 | Lower success due to overshoot after the optimum. |

## 8. Experiment Plan

The project includes four experiments:

| Experiment | Qubits | Target | Iterations | Purpose |
|---|---:|---|---:|---|
| 1 | 2 | `|11⟩` | 1 | Basic validation on a 4-state search space. |
| 2 | 3 | `|101⟩` | 2 | Validate the optimal iteration count on an 8-state search space. |
| 3 | 3 | `|101⟩` | 1 | Observe the effect of too few iterations. |
| 4 | 3 | `|101⟩` | 3 | Observe the overshoot effect after the optimum. |

Each experiment is run for 100 shots. The success rate is computed by counting how many measurements match the target value.

The expected result is that the optimal iteration experiments should produce high success rates, while the under-iterated and over-iterated cases should produce lower success rates.

## 9. Debug and Validation Plan

In addition to statistical testing, the project includes a debug run with `DumpMachine()`.

The debug run is performed on the 2-qubit `|11⟩` example and checks the state after each major step:

| Step | Expected State Behavior |
|---|---|
| Initial state | Only `|00⟩` has amplitude 1. |
| After `PrepareUniform` | All four states have amplitude 0.5 and probability 25%. |
| After `MarkTarget` | Probabilities remain unchanged, but the target state's phase becomes negative. |
| After `ReflectAboutUniform` | The target state's amplitude is amplified to probability 100% in the 2-qubit case. |

This debug step is important because the oracle's effect cannot be fully understood from measurement alone. A phase flip does not immediately change measurement probabilities, so inspecting the state vector with the simulator helps verify that the oracle behaves correctly.

## 10. Design Decisions

The implementation uses `within/apply` in both the oracle and diffusion steps. This choice reflects the common quantum programming pattern of preparing a temporary transformation, applying the main operation, and then uncomputing the temporary transformation.

No ancilla qubit is used in the final implementation. For 2–3 qubit examples, `Controlled Z(Most(inputQubits), Tail(inputQubits))` is sufficient to implement the required multi-controlled phase flip. This keeps the project simpler and more readable for a beginner-level implementation.

The oracle is designed with a `targetPattern : Bool[]` argument instead of being hard-coded for one state. This makes the project more flexible and supports the Week 4 mini-experiment requirement of changing the target item.

The project uses only a simulator. This matches the scope of the onboarding plan and allows inspection with `DumpMachine()`, which is useful for understanding state-vector behavior during learning.

## 11. Expected Outcome

The implementation is expected to show that Grover's algorithm increases the probability of measuring the marked state compared to random guessing.

For the 2-qubit case, the target `|11⟩` should be measured almost always after one iteration. For the 3-qubit case, the optimal 2-iteration experiment should produce a much higher success rate than the random baseline of 12.5%.

The experiments with 1 and 3 iterations on the 3-qubit case are expected to show that iteration count matters. In particular, the 3-iteration case should demonstrate overshoot, where applying Grover's iteration too many times reduces the probability of measuring the target state.

These expectations are later compared with actual simulator results in `RESULTS.md`.


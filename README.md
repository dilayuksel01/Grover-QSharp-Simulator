# Grover's Search Algorithm — Q# Simulator Project

> This project implements and validates **Grover's Search Algorithm** in Microsoft Q#, using only a local simulator.

## Project Overview

This project demonstrates Grover's Search Algorithm on small search spaces using Microsoft Q#. Grover's algorithm is a quantum search algorithm designed for finding a marked item in an unstructured search space.

In classical search, finding one marked item among \(N\) possible items may require \(O(N)\) queries in the worst case. Grover's algorithm reduces the query complexity to approximately \(O(\sqrt{N})\), which makes it one of the most important introductory examples of quantum algorithmic speedup.

The implementation in this repository focuses on beginner-friendly simulator examples:

| Experiment | Search Space | Target State | Purpose |
|---|---:|---|---|
| 1 | 2 qubits / 4 states | `|11⟩` | Basic Grover validation |
| 2 | 3 qubits / 8 states | `|101⟩` | Optimal iteration test |
| 3 | 3 qubits / 8 states | `|101⟩` | Too few iterations |
| 4 | 3 qubits / 8 states | `|101⟩` | Too many iterations / overshoot |

The project is intentionally small enough to understand step by step, but it goes beyond one-qubit toy examples by using a reusable oracle, a diffusion operator, multiple qubits, statistical testing, and simulator-based debugging.

## Learning Achievements

This project applies the core quantum programming concepts learned during the onboarding plan.

The first concept is **superposition**. The program starts from the `|0...0⟩` state and applies Hadamard gates to prepare a uniform superposition over all candidate answers:

$$
|s\rangle = \frac{1}{\sqrt{2^n}}\sum_{x=0}^{2^n-1}|x\rangle
$$

The second concept is **oracle-based phase marking**. The oracle does not measure or reveal the target state. Instead, it applies a negative phase to the marked basis state:

$$
|x_{\text{target}}\rangle \rightarrow -|x_{\text{target}}\rangle
$$

while leaving all other states unchanged.

The third concept is **amplitude amplification**. After the oracle marks the target state by phase, the diffusion operator reflects amplitudes about the average. This increases the probability of measuring the marked state.

The project also uses several Q# programming constructs:

| Q# Construct | How it is used |
|---|---|
| `operation` | Defines reusable quantum routines such as `GroverSearch`, `MarkTarget`, and `ReflectAboutUniform`. |
| `Qubit[]` | Represents the quantum register used as the search space. |
| `H`, `X`, `Controlled Z` | Implements superposition, basis transformation, and phase reflection. |
| `within/apply` | Encodes the prepare → apply → uncompute pattern cleanly. |
| `MResetEachZ` | Measures the qubits and safely resets them. |
| `Message()` | Prints experiment summaries. |
| `DumpMachine()` | Inspects simulator state vectors during debugging. |

## Repository Structure

```text
.
├── GroverSearch.qs      # Final Q# implementation
├── README.md            # Project documentation
├── DESIGN.md            # Phase 2 design document
├── RESULTS.md           # Phase 3 testing and result analysis
├── experiments/         # Small Q# practice files from the learning phase
└── screenshots/         # Optional run screenshots
```

The `experiments/` folder contains early Q# practice files written during the learning phase. The final project implementation is `GroverSearch.qs`.

## Methodology

The implementation follows the standard Grover structure: prepare a uniform superposition, apply the oracle, apply the diffusion operator, repeat the Grover iteration an optimal number of times, and finally measure the register.

At a high level, the algorithm is:

```text
1. Allocate n qubits in the |0...0⟩ state.
2. Apply H to every qubit to create a uniform superposition.
3. Apply the oracle to flip the phase of the target state.
4. Apply the diffusion operator to amplify the target state's amplitude.
5. Repeat oracle + diffusion for the chosen number of iterations.
6. Measure the register and record whether the result matches the target.
```

The core operation is `GroverSearch`:

```qsharp
operation GroverSearch(
    nQubits : Int,
    iterations : Int,
    targetPattern : Bool[]
) : Result[] {
    use qubits = Qubit[nQubits];

    PrepareUniform(qubits);

    for _ in 1..iterations {
        MarkTarget(targetPattern, qubits);
        ReflectAboutUniform(qubits);
    }

    return MResetEachZ(qubits);
}
```

### Uniform Superposition

`PrepareUniform` applies a Hadamard gate to each qubit:

```qsharp
operation PrepareUniform(inputQubits : Qubit[]) : Unit is Adj + Ctl {
    for q in inputQubits {
        H(q);
    }
}
```

For two qubits, this transforms `|00⟩` into:

$$
\frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)
$$

At this stage, each possible answer has equal probability.

### Oracle

The oracle is implemented by `MarkTarget`. It receives a `targetPattern : Bool[]`, which makes the implementation reusable for different marked states. For example, `[true, true]` marks `|11⟩`, while `[true, false, true]` marks `|101⟩`.

The oracle temporarily maps the chosen target pattern to the all-ones state, applies a phase reflection, and then uncomputes the temporary transformation:

```qsharp
operation MarkTarget(targetPattern : Bool[], inputQubits : Qubit[]) : Unit {
    if Length(targetPattern) != Length(inputQubits) {
        fail "Target pattern length must match the number of qubits.";
    }

    let lastIndex = Length(inputQubits) - 1;

    within {
        for i in 0..lastIndex {
            if not targetPattern[i] {
                X(inputQubits[i]);
            }
        }
    } apply {
        ReflectAboutAllOnes(inputQubits);
    }
}
```

This design avoids hard-coding a single target state and allows the same Grover implementation to be tested with multiple search targets.

### Diffusion Operator

The diffusion operator is implemented by `ReflectAboutUniform`. Its theoretical form is:

$$
D = 2|s\rangle\langle s| - I
$$

where `|s⟩` is the uniform superposition state.

In code, the diffusion step is implemented using the prepare → apply → uncompute pattern:

```qsharp
operation ReflectAboutUniform(inputQubits : Qubit[]) : Unit {
    within {
        Adjoint PrepareUniform(inputQubits);

        for q in inputQubits {
            X(q);
        }
    } apply {
        ReflectAboutAllOnes(inputQubits);
    }
}
```

This reflects the current state about the uniform superposition. After the oracle flips the target state's phase, the diffusion operator turns that phase difference into a larger measurement probability for the target.

### Optimal Iteration Count

For a single target state in an \(N = 2^n\) item search space, the success probability after \(k\) iterations is approximately:

$$
P(k) = \sin^2((2k + 1)\theta), \qquad \theta = \arcsin\left(\frac{1}{\sqrt{N}}\right)
$$

The project calculates the iteration count with:

```qsharp
function CalculateOptimalIterations(nQubits : Int) : Int {
    if nQubits > 63 {
        fail "This sample supports at most 63 qubits.";
    }

    let nItems = 1 <<< nQubits;
    let angle = ArcSin(1.0 / Sqrt(IntAsDouble(nItems)));
    let iterations = Round(0.25 * PI() / angle - 0.5);

    return iterations;
}
```

This is important because Grover's algorithm does not improve indefinitely with more iterations. Too few iterations under-amplify the target state, while too many iterations can overshoot the target and reduce the success probability.

## Testing & Results

The program was tested on the local Q# simulator using 100 shots per experiment. Each shot runs Grover's algorithm once and records whether the measured result matches the target state.

| Experiment | nQubits | Target | Iterations | Successes / 100 | Observed % | Theoretical % |
|---|---:|---|---:|---:|---:|---:|
| 1 | 2 | `|11⟩` | 1 | 100 / 100 | 100.0% | ~100.0% |
| 2 | 3 | `|101⟩` | 2 | 97 / 100 | 97.0% | ~94.5% |
| 3 | 3 | `|101⟩` | 1 | 77 / 100 | 77.0% | ~78.1% |
| 4 | 3 | `|101⟩` | 3 | 31 / 100 | 31.0% | ~32.9% |

The results match the theoretical behavior of Grover's algorithm. In the 2-qubit case, one Grover iteration amplifies the target state almost perfectly, producing 100/100 success in the simulator. In the 3-qubit case, the optimal iteration count gives a much higher success rate than random guessing. With \(N=8\), random guessing would only succeed with probability \(1/8 = 12.5\%\), while the optimal Grover run reached 97%.

The iteration experiments are especially important. With only one iteration, the 3-qubit problem reached 77% success, which is better than random guessing but lower than the optimal result. With three iterations, success dropped to 31%, demonstrating Grover's overshoot behavior. This confirms that choosing the right number of iterations is part of the algorithm, not just a performance detail.

Detailed test notes and debug observations are documented in [`RESULTS.md`](RESULTS.md).

## Debug Validation

A separate `DebugGroverOnce()` operation was used to inspect the intermediate simulator state with `DumpMachine()`.

The debug run confirmed the expected behavior:

| Step | Observation |
|---|---|
| Initial state | Only `|00⟩` has amplitude 1. |
| After `PrepareUniform` | All four states have amplitude 0.5 and probability 25%. |
| After oracle | Probabilities remain the same, but the target `|11⟩` receives a negative phase. |
| After diffusion | The target state's amplitude is amplified to probability 100% in the 2-qubit case. |

This validates that the oracle does not accidentally measure or directly change the target probability. It only changes the phase. The diffusion step then uses interference to convert that phase difference into amplitude amplification.

## Challenges & Solutions

The first conceptual challenge was understanding the role of the oracle. In Grover's algorithm, the oracle does not return the answer directly. It only marks the target state by changing its phase. This was clarified through `DumpMachine()` output: after the oracle, all probabilities stayed the same, while only the target state's amplitude changed sign.

The second challenge was avoiding a hard-coded oracle. A simple 2-qubit implementation can mark only `|11⟩` with a direct controlled-Z gate. However, this is too limited for a project. The final implementation uses `targetPattern : Bool[]`, which allows the same oracle logic to mark different states such as `|11⟩` and `|101⟩`.

The third challenge was implementing phase reflections cleanly. The project uses `ReflectAboutAllOnes` and the Q# `within/apply` construct to express the prepare → apply → uncompute pattern. This keeps the code readable and reduces the chance of forgetting to undo temporary transformations.

Another important observation came from testing different iteration counts. The experiments showed that more Grover iterations do not always improve the result. After the optimal point, the state vector overshoots the target direction and the success probability decreases.

## How to Run

This project is intended to run on the local Q# simulator. Open `GroverSearch.qs` in VS Code with the Q# extension installed, then run the `Main()` operation.

If using a Q# project structure with the .NET SDK, the project can be run with:

```bash
dotnet run
```

The output should print the number of successes for each experiment, for example:

```text
Experiment 1: 2 qubits, target |11>, optimal iteration
Successes = 100 / 100

Experiment 2: 3 qubits, target |101>, optimal iterations
Successes = 97 / 100

Experiment 3: 3 qubits, target |101>, too few iterations
Successes = 77 / 100

Experiment 4: 3 qubits, target |101>, more iterations
Successes = 31 / 100
```

Because the algorithm is probabilistic, exact success counts may vary slightly between runs.

## Next Steps

The next step would be testing larger search spaces such as 4 or 5 qubits. This would show the scaling behavior more clearly and make the optimal iteration count even more important.

Another extension would be supporting multiple marked states. In that case, the theoretical success probability needs to include the number of solutions \(M\), not only the search space size \(N\).

The project could also be extended with more formal Q# validation using assertion-based tests such as probability checks. In this implementation, `DumpMachine()` was used for educational debugging, but automated assertions would make the validation cleaner.

Finally, the code could be run on Azure Quantum simulators or, in the future, real quantum hardware. Real devices would introduce noise and hardware constraints, making it possible to compare ideal simulator behavior with physical execution.

## References

The project was developed using concepts and tools from:

- Microsoft Learn — Azure Quantum and Q# documentation
- Microsoft Quantum Development Kit (QDK)
- Microsoft Learn — Grover's Search Algorithm tutorial
- Microsoft Quantum Katas for introductory Q# practice

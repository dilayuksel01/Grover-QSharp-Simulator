// ============================================================
// Grover's Search Algorithm - Q# Demo
// ============================================================

import Std.Convert.*;
import Std.Math.*;
import Std.Arrays.*;
import Std.Measurement.*;
import Std.Diagnostics.*;

/// # Summary
/// Entry point. Runs several Grover experiments on 2 and 3 qubit
/// search spaces, then a debug run that prints the intermediate
/// quantum state after each step (superposition -> oracle -> diffusion).
operation Main() : Unit {
    Message("Grover Search Project - Simulator Only");
    Message(" ");

    Message("Experiment 1: 2 qubits, target |11>, optimal iteration");
    RunExperiment(2, [true, true], 3, 1, 100);
    Message(" ");

    Message("Experiment 2: 3 qubits, target |101>, optimal iterations");
    let optimalIterations3Qubits = CalculateOptimalIterations(3);
    RunExperiment(3, [true, false, true], 5, optimalIterations3Qubits, 100);
    Message(" ");

    Message("Experiment 3: 3 qubits, target |101>, too few iterations");
    RunExperiment(3, [true, false, true], 5, 1, 100);
    Message(" ");

    Message("Experiment 4: 3 qubits, target |101>, more iterations");
    RunExperiment(3, [true, false, true], 5, 3, 100);
    Message(" ");

    Message("Debug run: observing intermediate states for 2-qubit Grover, target |11>");
    let debugResult = DebugGroverOnce();
    Message($"Debug measurement result as integer: {ResultArrayAsInt(debugResult)}");
}

/// # Summary
/// Runs GroverSearch `shots` times and reports how many measurements
/// matched the target value. Used for statistical validation (Phase 3, Week 5).
operation RunExperiment(
    nQubits : Int,
    targetPattern : Bool[],
    targetValue : Int,
    iterations : Int,
    shots : Int
) : Unit {
    mutable successes = 0;
    for _ in 1..shots {
        let result = GroverSearch(nQubits, iterations, targetPattern);
        let measuredValue = ResultArrayAsInt(result);
        if measuredValue == targetValue {
            set successes += 1;
        }
    }
    Message($"nQubits = {nQubits}");
    Message($"Target value = {targetValue}");
    Message($"Iterations = {iterations}");
    Message($"Successes = {successes} / {shots}");
}

/// # Summary
/// Core Grover routine: prepare uniform superposition, then repeat
/// (oracle -> diffusion) `iterations` times, then measure.
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

/// # Summary
/// Computes the theoretically optimal number of Grover iterations
/// for a search space of size 2^nQubits with a single marked item.
function CalculateOptimalIterations(nQubits : Int) : Int {
    if nQubits > 63 {
        fail "This sample supports at most 63 qubits.";
    }
    let nItems = 1 <<< nQubits;
    let angle = ArcSin(1.0 / Sqrt(IntAsDouble(nItems)));
    let iterations = Round(0.25 * PI() / angle - 0.5);
    return iterations;
}

/// # Summary
/// Applies H to every qubit, creating an equal superposition over
/// all basis states.
operation PrepareUniform(inputQubits : Qubit[]) : Unit is Adj + Ctl {
    for q in inputQubits {
        H(q);
    }
}

/// # Summary
/// Oracle: flips the phase of the basis state matching `targetPattern`.
/// Uses X gates to map the target pattern onto |11...1>, applies a
/// multi-controlled Z, then uncomputes the X gates (within/apply).
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

/// # Summary
/// Applies a phase flip to the |11...1> basis state via a
/// multi-controlled Z gate.
operation ReflectAboutAllOnes(inputQubits : Qubit[]) : Unit {
    Controlled Z(Most(inputQubits), Tail(inputQubits));
}

/// # Summary
/// Diffusion / inversion-about-the-mean operator: reflects the
/// amplitudes about the average, amplifying the marked state.
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

/// # Summary
/// Debug helper: runs a single 2-qubit Grover iteration and dumps the
/// full quantum state after each stage, for learning/inspection purposes.
operation DebugGroverOnce() : Result[] {
    use qubits = Qubit[2];
    Message("Initial state |00>:");
    DumpMachine();

    PrepareUniform(qubits);
    Message("After PrepareUniform: equal superposition over |00>, |01>, |10>, |11>");
    DumpMachine();

    MarkTarget([true, true], qubits);
    Message("After Oracle: target |11> receives a phase flip");
    DumpMachine();

    ReflectAboutUniform(qubits);
    Message("After Diffusion: amplitude is amplified toward target |11>");
    DumpMachine();

    return MResetEachZ(qubits);
}

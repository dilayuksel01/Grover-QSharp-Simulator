# Test Results and Interpretation

> This document was prepared to test the Grover Search Q# project on a simulator, compare the results with theoretical expectations, and interpret the debug observations.

## 1. Theoretical Expectations

Grover's algorithm increases the probability of measuring the marked target state in an unstructured search space through **amplitude amplification**, rather than by directly measuring the answer. At the beginning, all possible states are placed into an equal superposition. If the search space contains $N$ states and there is a single target state, the probability of finding the correct answer by random guessing is:

$$
P_{\text{random}} = \frac{1}{N}
$$

Grover's algorithm amplifies the target state's amplitude by repeatedly applying the oracle and diffusion operations. In the single-target case, the success probability after $k$ Grover iterations is approximately:

$$
P(k) = \sin^2((2k + 1)\theta)
$$

where:

$$
\theta = \arcsin\left(\frac{1}{\sqrt{N}}\right)
$$

This formula shows the key behavior of Grover's algorithm: the success probability first increases as the number of iterations grows, but after the optimum point it starts to decrease again. Therefore, in Grover's algorithm, **more iterations do not always lead to better results**.

| Experiment | N (search space) | Iterations | Target | Theoretical P(success) |
|---|---:|---:|---|---:|
| 1 | 4 | 1 | `|11⟩` | ~100% |
| 2 | 8 | 2 (optimal) | `|101⟩` | ~94.5% |
| 3 | 8 | 1 | `|101⟩` | ~78.1% |
| 4 | 8 | 3 | `|101⟩` | ~32.9% |

For 3 qubits, the search space is $N = 2^3 = 8$. In this case, the random guessing success rate is only:

$$
\frac{1}{8} = 12.5\%
$$

For Grover's algorithm to be considered successful, the target state should be measured with a frequency significantly higher than this random guessing probability.

In this project, the optimal number of iterations for the 3-qubit case was calculated as 2. One iteration produces insufficient amplification, while 3 iterations pass the optimum point and cause **overshoot** behavior. Therefore, in Experiment 4, the success probability drops significantly compared to Experiment 2.

## 2. Actual Simulator Results

The Q# program was run on the local simulator with 100 shots for each experiment. Each shot means that the Grover algorithm was executed from start to finish once, and the measurement result was recorded. A measurement result was counted as a **success** when it matched the target value.

| Experiment | nQubits | Target | Target Value | Iterations | Successes / 100 | Observed % | Theoretical % | Difference |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | 2 | `|11⟩` | 3 | 1 | 100 / 100 | 100.0% | ~100.0% | 0 |
| 2 | 3 | `|101⟩` | 5 | 2 (optimal) | 97 / 100 | 97.0% | ~94.5% | +2.5 |
| 3 | 3 | `|101⟩` | 5 | 1 | 77 / 100 | 77.0% | ~78.1% | -1.1 |
| 4 | 3 | `|101⟩` | 5 | 3 | 31 / 100 | 31.0% | ~32.9% | -1.9 |

The results are consistent with the theoretical expectations. Small deviations of a few percentage points are normal for a 100-shot sample because measurement results are probabilistic. In particular, the observed success rates in Experiments 2, 3, and 4 are very close to the theoretical values. This shows that the implementation not only runs correctly, but also follows the expected mathematical behavior of Grover's algorithm.

In Experiment 1, a 2-qubit system and a 4-element search space were used. The target state was selected as `|11⟩`. In this special case, one Grover iteration almost completely isolates the target state, and the simulator produced 100/100 successful measurements.

In Experiment 2, the search space was increased to 3 qubits, meaning 8 possible states. The target state was set to `|101⟩`. With the optimal iteration count of 2, the success rate was measured as 97/100. This is far above the random guessing probability of 12.5%, clearly demonstrating the amplitude amplification effect of Grover's algorithm.

In Experiment 3, the same 3-qubit problem was run with only 1 iteration. The success rate dropped to 77/100. This result shows that the target state's amplitude had started to increase, but had not yet reached the optimum amplification level.

In Experiment 4, the same target was tested with 3 iterations. The success rate dropped to 31/100. This is the most important result for showing the periodic nature and overshoot behavior of Grover's algorithm. Once the optimal number of iterations is exceeded, the state vector does not keep moving closer to the target direction; instead, it passes the target direction and begins to move away from it. As a result, the success probability decreases again.

## 3. Debug Run and Intermediate-State Observations

In addition to statistical testing, the `DebugGroverOnce()` operation was used to inspect the intermediate steps of the algorithm. This operation runs the 2-qubit `|11⟩` target example as a single shot and displays the simulator's state vector after each important step using `DumpMachine()`.

The purpose of this debug run was to check whether the oracle and diffusion steps behaved as expected. On real quantum hardware, this kind of state-vector inspection is not possible; however, in a simulator environment, it is very useful for learning and validation.

At the beginning, the two qubits are in the `|00⟩` state. At this point, only the `|00⟩` state has amplitude 1, while all other states have amplitude 0. If a measurement were performed here, the result would certainly be `|00⟩`.

After applying the Hadamard gates, the system enters an equal superposition:

$$
\frac{1}{2}(|00\rangle + |01\rangle + |10\rangle + |11\rangle)
$$

At this stage, each of the four states has amplitude 0.5, and its probability is:

$$
|0.5|^2 = 0.25
$$

which corresponds to 25%. This confirms that the `PrepareUniform` operation works correctly.

After the oracle is applied, the probabilities do not change. Each of the four states still has a probability of 25%. However, the amplitude of the target state `|11⟩` changes from positive 0.5 to negative 0.5:

$$
|11\rangle : 0.5 \rightarrow -0.5
$$

This shows that the oracle does not measure the target state or directly increase its amplitude. The oracle only changes the phase of the target state. The transition from a positive amplitude to a negative amplitude can be interpreted as a phase shift of $\pi$ radians. In some simulator outputs, this phase may appear as $-\pi$; in this context, $\pi$ and $-\pi$ represent the same sign change.

After the diffusion step is applied, the phase difference created by the oracle is transformed into amplitude amplification. In the special 2-qubit case where $N=4$, after 1 iteration, the absolute value of the target state `|11⟩`'s amplitude reaches 1. Therefore, the measurement probability of the target state becomes 100%. The other three states do not appear in the measurement because their amplitudes drop to 0.

These debug observations confirm that each component of the algorithm works as expected: `PrepareUniform` creates an equal superposition, `MarkTarget` changes only the phase of the target state, and `ReflectAboutUniform` uses this phase difference to increase the probability of measuring the target state.

## 4. Interpretation of Results

The experimental results successfully demonstrate the core behavior of Grover's algorithm. First, when the optimal iteration count is used, the measurement frequency of the target state is much higher than random guessing. In the 2-qubit example, the random guessing success rate is 25%, while the Grover result is 100%. In the 3-qubit example, the random guessing success rate is 12.5%, while the success rate with the optimal iteration count reaches 97%.

This difference shows that Grover's algorithm does not search through the states one by one in the classical sense. Instead, it uses quantum interference to amplify the amplitude of the target state. The oracle marks the target state through a phase change, and the diffusion operation converts that phase marking into an increase in measurement probability.

Experiment 3 demonstrates the effect of using too few iterations. When the 3-qubit problem was run with only 1 iteration, the success rate was 77%. This is still much higher than random guessing, but lower than the 97% success rate obtained with the optimal 2 iterations. This indicates that the target state's amplitude had started increasing but had not yet reached the optimum amplification level.

Experiment 4 demonstrates overshoot behavior. When 3 iterations were used, the success rate dropped to 31%. This result is consistent with the geometric interpretation of Grover's algorithm: each oracle + diffusion pair rotates the state vector toward the target state direction by a certain angle. However, once the optimum point is passed, the vector starts moving away from the target state. As a result, the success probability decreases again.

Therefore, calculating the optimal number of iterations is critical in Grover's algorithm. Running more iterations does not always improve the result; once the optimum point is passed, the success probability can drop significantly and the advantage of the algorithm can weaken.

## 5. Challenges and Solutions

The first major conceptual challenge in this project was understanding the role of the oracle. At first, it can be tempting to think that the oracle directly finds or measures the target state. However, in Grover's algorithm, the oracle does not perform a measurement; it only changes the phase of the target state. This distinction was clarified using the `DumpMachine()` outputs. After the oracle step, the probabilities of all states remained the same, while only the target state's amplitude changed sign. This observation confirmed that the oracle was designed correctly.

The second challenge was making the oracle reusable instead of writing it for only one fixed target. In the initial approach, using `Controlled Z` directly was enough for the `|11⟩` target. However, that method was only suitable for a fixed 2-qubit example. To create a more flexible design, `targetPattern : Bool[]` was used. This made it possible to test target states such as `|11⟩`, `|101⟩`, or any other bit pattern.

The third challenge was implementing the multi-controlled phase flip in a clean and readable way. For this purpose, the `ReflectAboutAllOnes` operation was created, using `Controlled Z(Most(inputQubits), Tail(inputQubits))`. This approach made it possible to flip the phase of the target state for small qubit counts without using an additional ancilla qubit.

Another important learning point was the use of the `within/apply` structure. In the oracle and diffusion steps, some preparation gates are applied first, then the actual phase flip is performed, and finally the preparation steps must be undone. The `within/apply` pattern expresses this “prepare → apply → uncompute” flow in a clean and safe way.

Finally, the effect of the iteration count was clarified through experiments. Initially, it might seem reasonable to assume that more Grover iterations would produce better results. However, Experiment 4 showed that 3 iterations reduced the success rate to 31%. This result demonstrates that calculating the optimal number of iterations is necessary for the algorithm to work successfully.

## 6. Overall Conclusion

The tests confirmed that the Grover Search implementation works as expected. The code can find the target state with high probability in small search spaces. The results are consistent with the theoretical success probabilities, and the small deviations in the measurement results are normal for a 100-shot sample.

The project also demonstrates three fundamental quantum ideas in practice: superposition, phase marking, and amplitude amplification. `PrepareUniform` places all candidate states into an equal superposition; `MarkTarget` changes the phase of the target state; and `ReflectAboutUniform` increases the probability of measuring the target state.

One of the most important conclusions is that the number of Grover iterations must be chosen carefully. When the optimal iteration count is used, the success rate becomes very high. However, when the optimum point is passed, the success rate decreases due to overshoot. This behavior is clearly visible by comparing Experiment 2 and Experiment 4.

Therefore, the project does not only present working Q# code; it also validates the theoretical behavior of the algorithm using simulator results.

## 7. Next Steps

In the next stage of this project, larger search spaces can be tested. For example, using 4 or 5 qubits would create search spaces of $N=16$ or $N=32$ elements. For larger values of $N$, the effect of the optimal iteration count and the overshoot behavior become more clearly visible.

The oracle can also be extended to support multiple target states. In that case, the theoretical success formula should be reconsidered to include the number of target states $M$:

$$
\theta = \arcsin\left(\sqrt{\frac{M}{N}}\right)
$$

In addition, more formal unit-test-like checks can be added using Q# validation tools such as `AssertMeasurement`, `AssertProb`, or similar operations. This project used `DumpMachine()` during debugging to inspect intermediate states; in future versions, assert-based tests could make validation more automated.

Finally, the project currently runs only on the local simulator. In the future, it could be tested on Azure Quantum cloud simulators or suitable real quantum hardware. On real hardware, noise, error rates, and limited qubit connectivity may affect the results, so this would be a useful next step for observing the difference between simulator behavior and physical quantum devices.

In this programming assignment (PA4) you will develop the D&C parallelization of PolyMult.  First write DCQ, evaluate it in comparison with the earlier sequential variants, and then parallelize it.  For this, you goals are to:

- Demonstrate perfect speedup (or as close to perfect as you can) with the usual reduction strategy (using tasks, taskgroups etc.)
- Show the best speedup you can get without using reductions but with appropriate and correctly placed syncs (taskwaits).  You must first analyze the work and span of this program and use that to predict the parallel performance before actually running the experiment.
- One of the following two (optionally both):
	- Propose and develop another coarse grain parallelization strategy that avoids races without reductions
	- Continue to work the low level vectorization (of the leaf, aiming to get to TPP).

Please submit: your code as a tar file,  and your report as a separate pdf file.
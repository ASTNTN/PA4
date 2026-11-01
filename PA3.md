# PA3

This is the next program in the series as discussed in the lecture Monday Sep 28.  For this one you should block the OPQ code and explore different ways to optimize it.  Specifically

1. Optimize it on a single core (i.e., vectorize, fine grain optimization) and explore different options (as explained in the GSP series).  For this you don't have to consider races, or any other OpenMP issues.

2. Now extend this to parallelize across blocks.  You will use coarse grain parallelism across multiple cores, i.e., different cores execute different blocks/tiles in some parallel way.  Within the block you should plan to use the single-core vectorized code of Part A.  This is where you have to worry about races.   There are many different ways to do this. You should at least explore
	- Using the reduction clause.  Some of you had correctness issues.  Look up the documentation (or ask Claude to explain subtle details).  Recent OpenMP releases allow you to specify arrays (rather than just scalar variables) as the reduction target.
	- Without the reduction clause you can use different synchronization strategies to make sure that the program is race free.  As described in class, you can exploit the fact that the races are pairwise in each direction, (i.e., a tile has a race only with its immediate four neighbors) so there is pattern of independent tiles that are guaranteed to be race free.  You have many different ways in which to play with the outer two inter-tile loops to exploit parallelism that is possible from this observation.

As always the goal is to get as close to TPP as possible, and as you have seen, it requires a you to exploit both fine grain and coarse grain parallelism.

Submit both your report (as a pdf file) and your code (as a separate tar file).
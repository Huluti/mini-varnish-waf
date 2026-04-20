.PHONY: benchmark test

test:
	cd test && ./test.sh && cd ..

benchmark:
	cd benchmark && ./benchmark.sh && cd ..

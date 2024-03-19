module nxt.cpuid_ex;

version (none) {
/**
   See_Also: http://blog.melkerlitsgard.se/2016/05/12/cache-sizes-with-cpuid/
*/
	int getCacheSize(int cacheLevel) {
		// Intel stores it's cache information in eax4, with ecx as index
		// The information received is as following:
		// ebx[31:22] = Ways of associativity
		// ebx[21:12] = Physical line partitions
		// ebx[11: 0] = Line size
		int[4] cpuInfo = 0;
		asm
		{
			mov EAX, functionID;
			mov ECX, cacheLevl; // The index here is the cache level (0 = L1i, 1 = L1d, 2 = L2 etc.)
			cpuid;
			mov cpuInfo, EAX;
			mov cpuInfo + 4, EBX;
			mov cpuInfo + 8, ECX;
			mov cpuInfo + 12, EDX;
		}
		int ways = cpuInfo[1] & 0xffc00000; // This receives bit 22 to 31 from the ebx register
		ways >>= 22; // Bitshift it 22 bits to get the real value, since we started reading from bit 22
		int partitions = cpuInfo[1] & 0x7fe00; // This receives bit 12 to 22
		partitions >>= 12; // Same here, bitshift 12 bits
		int lineSize = cpuInfo[1] & 0x7ff; // This receives bit 0 to 11
		int sets = cpuInfo[2]; // The sets are the value of the ecx register
		// All of these values needs one appended to them to get the real value
		return (ways + 1) * (partitions + 1) * (lineSize + 1) * (sets + 1);
	}
}

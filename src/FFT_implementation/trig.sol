// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Solidity library offering basic trigonometry functions where inputs and outputs are
 * integers. Inputs are specified in radians scaled by 1e18, and similarly outputs are scaled by 1e18.
 *
 * This implementation is based off the Solidity trigonometry library written by Lefteris Karapetsas
 * which can be found here: https://github.com/Sikorkaio/sikorka/blob/e75c91925c914beaedf4841c0336a806f2b5f66d/contracts/trigonometry.sol
 *
 * Compared to Lefteris' implementation, this version makes the following changes:
 *   - Uses a 32 bits instead of 16 bits for improved accuracy
 *   - Updated for Solidity 0.8.x
 *   - Various gas optimizations
 *   - Change inputs/outputs to standard trig format (scaled by 1e18) instead of requiring the
 *     integer format used by the algorithm
 *
 * Lefertis' implementation is based off Dave Dribin's trigint C library
 *     http://www.dribin.org/dave/trigint/
 *
 * Which in turn is based from a now deleted article which can be found in the Wayback Machine:
 *     http://web.archive.org/web/20120301144605/http://www.dattalo.com/technical/software/pic/picsine.html
 */
library Trigonometry {
    // Table index into the trigonometric table
    uint256 constant INDEX_WIDTH = 8;
    // Interpolation between successive entries in the table
    uint256 constant INTERP_WIDTH = 16;
    uint256 constant INDEX_OFFSET = 28 - INDEX_WIDTH;
    uint256 constant INTERP_OFFSET = INDEX_OFFSET - INTERP_WIDTH;
    uint32 constant ANGLES_IN_CYCLE = 1073741824;
    uint32 constant QUADRANT_HIGH_MASK = 536870912;
    uint32 constant QUADRANT_LOW_MASK = 268435456;
    uint256 constant SINE_TABLE_SIZE = 256;

    // Pi as an 18 decimal value, which is plenty of accuracy: "For JPL's highest accuracy calculations, which are for
    // interplanetary navigation, we use 3.141592653589793: https://www.jpl.nasa.gov/edu/news/2016/3/16/how-many-decimals-of-pi-do-we-really-need/
    uint256 constant PI = 3141592653589793238;
    uint256 constant TWO_PI = 2 * PI;
    uint256 constant PI_OVER_TWO = PI / 2;

    // The constant sine lookup table was generated by generate_trigonometry.py. We must use a constant
    // bytes array because constant arrays are not supported in Solidity. Each entry in the lookup
    // table is 4 bytes. Since we're using 32-bit parameters for the lookup table, we get a table size
    // of 2^(32/4) + 1 = 257, where the first and last entries are equivalent (hence the table size of
    // 256 defined above)
    uint8 constant entry_bytes = 4; // each entry in the lookup table is 4 bytes
    uint256 constant entry_mask = ((1 << 8 * entry_bytes) - 1); // mask used to cast bytes32 -> lookup table entry
    bytes constant sin_table =
        hex"0000000000c90f8801921d20025b26d703242abf03ed26e604b6195d057f00350647d97c0710a34507d95b9e08a2009a096a90490a3308bc0afb68050bc3ac350c8bd35e0d53db920e1bc2e40ee387660fab272b1072a0481139f0cf120116d512c8106e138edbb1145576b1151bdf8515e2144416a81305176dd9de183366e818f8b83c19bdcbf31a82a0251b4732ef1c0b826a1ccf8cb31d934fe51e56ca1e1f19f97b1fdcdc1b209f701c2161b39f2223a4c522e541af23a6887e2467775725280c5d25e845b626a8218527679df42826b92828e5714a29a3c4852a61b1012b1f34eb2bdc4e6f2c98fbba2d553afb2e110a622ecc681e2f8752623041c76030fbc54d31b54a5d326e54c73326e2c233def2873496824f354d905636041ad936ba2013376f9e46382493b038d8fe93398cdd323a402dd13af2eeb73ba51e293c56ba703d07c1d53db832a53e680b2c3f1749b73fc5ec974073f21d4121589a41ce1e64427a41d04325c13543d09aec447acd50452456bc45cd358f46756827471cece647c3c22e4869e664490f57ee49b415334a581c9d4afb6c974b9e038f4c3fdff34ce100344d8162c34e2106174ebfe8a44f5e08e24ffb654c5097fc5e5133cc9451ced46e5269126e53028517539b2aef5433027d54ca0a4a556040e255f5a4d2568a34a9571deef957b0d2555842dd5458d40e8c5964649759f3de125a8279995b1035ce5b9d11535c290acc5cb420df5d3e52365dc79d7b5e50015d5ed77c895f5e0db25fe3b38d60686cce60ec382f616f146b61f1003e6271fa6862f201ac637114cc63ef328f646c59bf64e889256563bf9165ddfbd266573cbb66cf811f6746c7d767bd0fbc683257aa68a69e806919e31f698c246b69fd614a6a6d98a36adcc9646b4af2786bb812d06c24295f6c8f351b6cf934fb6d6227f96dca0d146e30e3496e96a99c6efb5f116f5f02b16fc1938470231099708378fe70e2cbc571410804719e2cd171fa394872552c8472af05a67307c3cf735f662573b5ebd0740b53fa745f9dd074b2c8837504d3447555bd4b75a585ce75f42c0a7641af3c768e0ea576d9498877235f2c776c4eda77b417df77fab988784033287884841378c7aba17909a92c794a7c11798a23b079c89f6d7a05eeac7a4210d87a7d055a7ab6cba37aef63237b26cb4e7b5d039d7b920b887bc5e28f7bf8882f7c29fbed7c5a3d4f7c894bdd7cb727237ce3ceb17d0f42177d3980eb7d628ac57d8a5f3f7db0fdf77dd6668e7dfa98a77e1d93e97e3f57fe7e5fe4927e7f39567e9d55fb7eba3a387ed5e5c57ef0585f7f0991c37f2191b37f3857f57f4de4507f62368e7f754e7f7f872bf27f97cebc7fa736b37fb563b27fc255957fce0c3d7fd8878d7fe1c76a7fe9cbbf7ff094777ff621817ffa72d07ffd88597fff62157fffffff";

    /**
     * @notice Return the sine of a value, specified in radians scaled by 1e18
     * @dev This algorithm for converting sine only uses integer values, and it works by dividing the
     * circle into 30 bit angles, i.e. there are 1,073,741,824 (2^30) angle units, instead of the
     * standard 360 degrees (2pi radians). From there, we get an output in range -2,147,483,647 to
     * 2,147,483,647, (which is the max value of an int32) which is then converted back to the standard
     * range of -1 to 1, again scaled by 1e18
     * @param _angle Angle to convert
     * @return Result scaled by 1e18
     */
    function sin(uint256 _angle) internal pure returns (int256) {
        unchecked {
            // Convert angle from from arbitrary radian value (range of 0 to 2pi) to the algorithm's range
            // of 0 to 1,073,741,824
            _angle = ANGLES_IN_CYCLE * (_angle % TWO_PI) / TWO_PI;

            // Apply a mask on an integer to extract a certain number of bits, where angle is the integer
            // whose bits we want to get, the width is the width of the bits (in bits) we want to extract,
            // and the offset is the offset of the bits (in bits) we want to extract. The result is an
            // integer containing _width bits of _value starting at the offset bit
            uint256 interp = (_angle >> INTERP_OFFSET) & ((1 << INTERP_WIDTH) - 1);
            uint256 index = (_angle >> INDEX_OFFSET) & ((1 << INDEX_WIDTH) - 1);

            // The lookup table only contains data for one quadrant (since sin is symmetric around both
            // axes), so here we figure out which quadrant we're in, then we lookup the values in the
            // table then modify values accordingly
            bool is_odd_quadrant = (_angle & QUADRANT_LOW_MASK) == 0;
            bool is_negative_quadrant = (_angle & QUADRANT_HIGH_MASK) != 0;

            if (!is_odd_quadrant) {
                index = SINE_TABLE_SIZE - 1 - index;
            }

            bytes memory table = sin_table;
            // We are looking for two consecutive indices in our lookup table
            // Since EVM is left aligned, to read n bytes of data from idx i, we must read from `i * data_len` + `n`
            // therefore, to read two entries of size entry_bytes `index * entry_bytes` + `entry_bytes * 2`
            uint256 offset1_2 = (index + 2) * entry_bytes;

            // This following snippet will function for any entry_bytes <= 15
            uint256 x1_2;
            assembly {
                // mload will grab one word worth of bytes (32), as that is the minimum size in EVM
                x1_2 := mload(add(table, offset1_2))
            }

            // We now read the last two numbers of size entry_bytes from x1_2
            // in example: entry_bytes = 4; x1_2 = 0x00...12345678abcdefgh
            // therefore: entry_mask = 0xFFFFFFFF

            // 0x00...12345678abcdefgh >> 8*4 = 0x00...12345678
            // 0x00...12345678 & 0xFFFFFFFF = 0x12345678
            uint256 x1 = x1_2 >> 8 * entry_bytes & entry_mask;
            // 0x00...12345678abcdefgh & 0xFFFFFFFF = 0xabcdefgh
            uint256 x2 = x1_2 & entry_mask;

            // Approximate angle by interpolating in the table, accounting for the quadrant
            uint256 approximation = ((x2 - x1) * interp) >> INTERP_WIDTH;
            int256 sine = is_odd_quadrant ? int256(x1) + int256(approximation) : int256(x2) - int256(approximation);
            if (is_negative_quadrant) {
                sine *= -1;
            }

            // Bring result from the range of -2,147,483,647 through 2,147,483,647 to -1e18 through 1e18.
            // This can never overflow because sine is bounded by the above values
            return sine * 1e18 / 2_147_483_647;
        }
    }

    /**
     * @notice Return the cosine of a value, specified in radians scaled by 1e18
     * @dev This is identical to the sin() method, and just computes the value by delegating to the
     * sin() method using the identity cos(x) = sin(x + pi/2)
     * @dev Overflow when `angle + PI_OVER_TWO > type(uint256).max` is ok, results are still accurate
     * @param _angle Angle to convert
     * @return Result scaled by 1e18
     */
    function cos(uint256 _angle) internal pure returns (int256) {
        unchecked {
            return sin(_angle + PI_OVER_TWO);
        }
    }
}

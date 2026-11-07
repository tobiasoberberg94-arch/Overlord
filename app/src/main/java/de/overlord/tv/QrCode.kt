package de.overlord.tv

/**
 * Kleiner QR-Code-Generator (Byte-Modus, Fehlerkorrektur M, Versionen 1–40) ohne Bibliothek.
 * Folgt dem Standard ISO/IEC 18004: Datenkodierung, Reed-Solomon, Verschachtelung,
 * Funktionsmuster, Maskenwahl nach Strafpunkten.
 */
class QrCode private constructor(val size: Int, private val modules: Array<BooleanArray>) {

    fun isDark(x: Int, y: Int): Boolean = x in 0 until size && y in 0 until size && modules[y][x]

    companion object {
        private val ECC_PER_BLOCK_M = intArrayOf(
            -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
            26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
        )
        private val NUM_BLOCKS_M = intArrayOf(
            -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
            17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
        )
        private const val ECL_FORMAT_M = 0

        fun encode(text: String): QrCode {
            val data = text.toByteArray(Charsets.UTF_8)
            var version = 1
            while (true) {
                val cap = numDataCodewords(version) * 8
                val needed = 4 + (if (version < 10) 8 else 16) + data.size * 8
                if (needed <= cap) break
                version++
                require(version <= 40) { "Text zu lang für einen QR-Code" }
            }
            // Bitstrom
            val bits = BitBuffer()
            bits.append(0x4, 4)
            bits.append(data.size, if (version < 10) 8 else 16)
            data.forEach { bits.append(it.toInt() and 0xFF, 8) }
            val capBits = numDataCodewords(version) * 8
            bits.append(0, minOf(4, capBits - bits.size))
            bits.append(0, (8 - bits.size % 8) % 8)
            var pad = 0xEC
            while (bits.size < capBits) { bits.append(pad, 8); pad = pad xor (0xEC xor 0x11) }
            val dataCodewords = ByteArray(bits.size / 8)
            for (i in 0 until bits.size) if (bits[i]) dataCodewords[i ushr 3] = (dataCodewords[i ushr 3].toInt() or (1 shl (7 - (i and 7)))).toByte()

            val all = addEccAndInterleave(dataCodewords, version)
            val size = version * 4 + 17
            val modules = Array(size) { BooleanArray(size) }
            val isFunction = Array(size) { BooleanArray(size) }
            drawFunctionPatterns(version, size, modules, isFunction)
            drawCodewords(all, size, modules, isFunction)

            var bestMask = 0
            var bestPenalty = Int.MAX_VALUE
            for (mask in 0 until 8) {
                applyMask(mask, size, modules, isFunction)
                drawFormatBits(mask, size, modules, isFunction)
                val p = penalty(size, modules)
                if (p < bestPenalty) { bestPenalty = p; bestMask = mask }
                applyMask(mask, size, modules, isFunction) // rückgängig (XOR)
            }
            applyMask(bestMask, size, modules, isFunction)
            drawFormatBits(bestMask, size, modules, isFunction)
            return QrCode(size, modules)
        }

        private class BitBuffer {
            private val bits = ArrayList<Boolean>()
            val size get() = bits.size
            operator fun get(i: Int) = bits[i]
            fun append(value: Int, len: Int) {
                for (i in len - 1 downTo 0) bits.add(((value ushr i) and 1) != 0)
            }
        }

        private fun numRawDataModules(ver: Int): Int {
            var result = (16 * ver + 128) * ver + 64
            if (ver >= 2) {
                val numAlign = ver / 7 + 2
                result -= (25 * numAlign - 10) * numAlign - 55
                if (ver >= 7) result -= 36
            }
            return result
        }

        private fun numDataCodewords(ver: Int) = numRawDataModules(ver) / 8 - ECC_PER_BLOCK_M[ver] * NUM_BLOCKS_M[ver]

        private fun addEccAndInterleave(data: ByteArray, ver: Int): ByteArray {
            val numBlocks = NUM_BLOCKS_M[ver]
            val blockEccLen = ECC_PER_BLOCK_M[ver]
            val rawCodewords = numRawDataModules(ver) / 8
            val numShortBlocks = numBlocks - rawCodewords % numBlocks
            val shortBlockLen = rawCodewords / numBlocks
            val divisor = rsDivisor(blockEccLen)
            val blocks = ArrayList<ByteArray>()
            var k = 0
            for (i in 0 until numBlocks) {
                val datLen = shortBlockLen - blockEccLen + (if (i < numShortBlocks) 0 else 1)
                val dat = data.copyOfRange(k, k + datLen)
                k += datLen
                val ecc = rsRemainder(dat, divisor)
                val block = ByteArray(shortBlockLen + 1)
                System.arraycopy(dat, 0, block, 0, dat.size)
                // Kurze Blöcke bekommen eine Lücke an Position datLen (wird beim Verschachteln übersprungen)
                val eccStart = shortBlockLen + 1 - blockEccLen
                System.arraycopy(ecc, 0, block, eccStart, ecc.size)
                blocks.add(block)
            }
            val result = ByteArray(rawCodewords)
            var idx = 0
            for (i in 0 until shortBlockLen + 1) {
                for (j in blocks.indices) {
                    if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) {
                        result[idx++] = blocks[j][i]
                    }
                }
            }
            return result
        }

        private fun rsMul(x: Int, y: Int): Int {
            var z = 0
            for (i in 7 downTo 0) {
                z = (z shl 1) xor ((z ushr 7) * 0x11D)
                z = z xor (((y ushr i) and 1) * x)
            }
            return z and 0xFF
        }

        private fun rsDivisor(degree: Int): IntArray {
            val result = IntArray(degree)
            result[degree - 1] = 1
            var root = 1
            for (i in 0 until degree) {
                for (j in 0 until degree) {
                    result[j] = rsMul(result[j], root)
                    if (j + 1 < degree) result[j] = result[j] xor result[j + 1]
                }
                root = rsMul(root, 0x02)
            }
            return result
        }

        private fun rsRemainder(data: ByteArray, divisor: IntArray): ByteArray {
            val result = IntArray(divisor.size)
            for (b in data) {
                val factor = (b.toInt() and 0xFF) xor result[0]
                System.arraycopy(result, 1, result, 0, result.size - 1)
                result[result.size - 1] = 0
                for (i in result.indices) result[i] = result[i] xor rsMul(divisor[i], factor)
            }
            return ByteArray(result.size) { result[it].toByte() }
        }

        private fun set(m: Array<BooleanArray>, f: Array<BooleanArray>, x: Int, y: Int, dark: Boolean) {
            m[y][x] = dark
            f[y][x] = true
        }

        private fun alignmentPositions(ver: Int, size: Int): IntArray {
            if (ver == 1) return IntArray(0)
            val numAlign = ver / 7 + 2
            val step = if (ver == 32) 26 else (ver * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2) * 2
            val result = IntArray(numAlign)
            result[0] = 6
            var pos = size - 7
            for (i in numAlign - 1 downTo 1) { result[i] = pos; pos -= step }
            return result
        }

        private fun drawFunctionPatterns(ver: Int, size: Int, m: Array<BooleanArray>, f: Array<BooleanArray>) {
            for (i in 0 until size) {
                set(m, f, 6, i, i % 2 == 0)
                set(m, f, i, 6, i % 2 == 0)
            }
            fun finder(cx: Int, cy: Int) {
                for (dy in -4..4) for (dx in -4..4) {
                    val dist = maxOf(Math.abs(dx), Math.abs(dy))
                    val x = cx + dx
                    val y = cy + dy
                    if (x in 0 until size && y in 0 until size) set(m, f, x, y, dist != 2 && dist != 4)
                }
            }
            finder(3, 3)
            finder(size - 4, 3)
            finder(3, size - 4)
            val align = alignmentPositions(ver, size)
            for (i in align.indices) for (j in align.indices) {
                if ((i == 0 && j == 0) || (i == 0 && j == align.size - 1) || (i == align.size - 1 && j == 0)) continue
                for (dy in -2..2) for (dx in -2..2) set(m, f, align[i] + dx, align[j] + dy, maxOf(Math.abs(dx), Math.abs(dy)) != 1)
            }
            // Format-Bereiche reservieren (werden später beschrieben)
            drawFormatBits(0, size, m, f)
            if (ver >= 7) {
                var rem = ver
                for (i in 0 until 12) rem = (rem shl 1) xor ((rem ushr 11) * 0x1F25)
                val bits = (ver shl 12) or rem
                for (i in 0 until 18) {
                    val bit = ((bits ushr i) and 1) != 0
                    val a = size - 11 + i % 3
                    val b = i / 3
                    set(m, f, a, b, bit)
                    set(m, f, b, a, bit)
                }
            }
        }

        private fun drawFormatBits(mask: Int, size: Int, m: Array<BooleanArray>, f: Array<BooleanArray>) {
            val data = (ECL_FORMAT_M shl 3) or mask
            var rem = data
            for (i in 0 until 10) rem = (rem shl 1) xor ((rem ushr 9) * 0x537)
            val bits = ((data shl 10) or rem) xor 0x5412
            fun bit(i: Int) = ((bits ushr i) and 1) != 0
            for (i in 0..5) set(m, f, 8, i, bit(i))
            set(m, f, 8, 7, bit(6))
            set(m, f, 8, 8, bit(7))
            set(m, f, 7, 8, bit(8))
            for (i in 9 until 15) set(m, f, 14 - i, 8, bit(i))
            for (i in 0 until 8) set(m, f, size - 1 - i, 8, bit(i))
            for (i in 8 until 15) set(m, f, 8, size - 15 + i, bit(i))
            set(m, f, 8, size - 8, true)
        }

        private fun drawCodewords(data: ByteArray, size: Int, m: Array<BooleanArray>, f: Array<BooleanArray>) {
            var i = 0
            var right = size - 1
            while (right >= 1) {
                if (right == 6) right = 5
                for (vert in 0 until size) {
                    for (j in 0 until 2) {
                        val x = right - j
                        val upward = ((right + 1) and 2) == 0
                        val y = if (upward) size - 1 - vert else vert
                        if (!f[y][x] && i < data.size * 8) {
                            m[y][x] = ((data[i ushr 3].toInt() ushr (7 - (i and 7))) and 1) != 0
                            i++
                        }
                    }
                }
                right -= 2
            }
        }

        private fun applyMask(mask: Int, size: Int, m: Array<BooleanArray>, f: Array<BooleanArray>) {
            for (y in 0 until size) for (x in 0 until size) {
                if (f[y][x]) continue
                val invert = when (mask) {
                    0 -> (x + y) % 2 == 0
                    1 -> y % 2 == 0
                    2 -> x % 3 == 0
                    3 -> (x + y) % 3 == 0
                    4 -> (x / 3 + y / 2) % 2 == 0
                    5 -> x * y % 2 + x * y % 3 == 0
                    6 -> (x * y % 2 + x * y % 3) % 2 == 0
                    else -> ((x + y) % 2 + x * y % 3) % 2 == 0
                }
                if (invert) m[y][x] = !m[y][x]
            }
        }

        private fun penalty(size: Int, m: Array<BooleanArray>): Int {
            var result = 0
            // N1: lange Läufe gleicher Farbe
            for (y in 0 until size) {
                var run = 1
                for (x in 1 until size) {
                    if (m[y][x] == m[y][x - 1]) { run++; if (run == 5) result += 3 else if (run > 5) result++ } else run = 1
                }
            }
            for (x in 0 until size) {
                var run = 1
                for (y in 1 until size) {
                    if (m[y][x] == m[y - 1][x]) { run++; if (run == 5) result += 3 else if (run > 5) result++ } else run = 1
                }
            }
            // N2: 2×2-Blöcke
            for (y in 0 until size - 1) for (x in 0 until size - 1) {
                val c = m[y][x]
                if (c == m[y][x + 1] && c == m[y + 1][x] && c == m[y + 1][x + 1]) result += 3
            }
            // N3: Finder-ähnliche Muster 1:1:3:1:1 mit hellem Rand
            val p1 = booleanArrayOf(true, false, true, true, true, false, true, false, false, false, false)
            val p2 = booleanArrayOf(false, false, false, false, true, false, true, true, true, false, true)
            fun matches(get: (Int) -> Boolean, pattern: BooleanArray) = pattern.indices.all { get(it) == pattern[it] }
            for (y in 0 until size) for (x in 0..size - 11) {
                if (matches({ m[y][x + it] }, p1) || matches({ m[y][x + it] }, p2)) result += 40
            }
            for (x in 0 until size) for (y in 0..size - 11) {
                if (matches({ m[y + it][x] }, p1) || matches({ m[y + it][x] }, p2)) result += 40
            }
            // N4: Verhältnis dunkel/hell
            var dark = 0
            for (row in m) for (b in row) if (b) dark++
            val total = size * size
            val k = (Math.abs(dark * 20 - total * 10) + total - 1) / total - 1
            result += maxOf(0, k) * 10
            return result
        }
    }
}

//
//  PipeLevels.swift
//  TapInApp
//
//  Each puzzle was designed solution-first: a complete 5x5 grid was filled
//  with contiguous color paths, then only the two endpoints of each path
//  were kept. Every puzzle is verified solvable.
//

import Foundation

extension PipePuzzle {

    // Helper to shorten definitions
    private static func pos(_ r: Int, _ c: Int) -> PipePosition {
        PipePosition(row: r, col: c)
    }
    private static func pair(_ color: PipeColor, _ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> PipeEndpointPair {
        PipeEndpointPair(color: color, start: pos(r1, c1), end: pos(r2, c2))
    }

    /// Pool of daily puzzles — cycled via dayOfYear
    static let puzzles: [PipePuzzle] = [

        // -------------------------------------------------------
        // P1  (Easy — gentle turns)
        // Solution:
        //   R R R . B       R: (0,0)→(0,1)→(0,2)→(1,2)→(1,3)
        //   G G R R B       B: (0,3)→(0,4)→(1,4)→(2,4)→(2,3)
        //   G G . B B       G: (1,0)→(1,1)→(2,1)→(2,0)→(3,0)
        //   G . Y Y O       Y: (2,2)→(3,2)→(3,1)→(4,1)→(4,0)
        //   Y Y O O O       O: (3,3)→(3,4)→(4,4)→(4,3)→(4,2)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  1, 3),
            pair(.blue,   0, 3,  2, 3),
            pair(.green,  1, 0,  3, 0),
            pair(.yellow, 2, 2,  4, 0),
            pair(.orange, 3, 3,  4, 2),
        ]),

        // -------------------------------------------------------
        // P2  (Medium — S-curves)
        // Solution:
        //   R R B B B       R: (0,0)→(0,1)→(1,1)→(1,0)→(2,0)
        //   R R G B B       B: (0,2)→(0,3)→(0,4)→(1,4)→(1,3)
        //   R G G Y Y       G: (1,2)→(2,2)→(2,1)→(3,1)→(3,0)
        //   G G Y Y Y       Y: (2,3)→(2,4)→(3,4)→(3,3)→(3,2)
        //   O O O O O       O: (4,0)→(4,1)→(4,2)→(4,3)→(4,4)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  2, 0),
            pair(.blue,   0, 2,  1, 3),
            pair(.green,  1, 2,  3, 0),
            pair(.yellow, 2, 3,  3, 2),
            pair(.orange, 4, 0,  4, 4),
        ]),

        // -------------------------------------------------------
        // P3  (Medium — U-turns)
        // Solution:
        //   R R B B B       R: (0,0)→(0,1)→(1,1)→(1,0)→(2,0)
        //   R R B G G       ..wait, let me redo with the actual
        //   ...             provider pattern. Using P4 design:
        //
        //   R R B B B       R: (0,0)→(0,1)→(1,1)→(1,0)
        //   R R B B B       B: (0,2)→(0,3)→(0,4)→(1,4)→(1,3)→(1,2)
        //   G G G G G       G: (2,0)→(2,1)→(2,2)→(2,3)→(2,4)
        //   Y Y Y O O       Y: (3,0)→(4,0)→(4,1)→(3,1)→(3,2)
        //   Y Y O O O       O: (3,3)→(3,4)→(4,4)→(4,3)→(4,2)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  1, 0),
            pair(.blue,   0, 2,  1, 2),
            pair(.green,  2, 0,  2, 4),
            pair(.yellow, 3, 0,  3, 2),
            pair(.orange, 3, 3,  4, 2),
        ]),

        // -------------------------------------------------------
        // P4  (Hard — interleaved)
        // Solution:
        //   R R R B B       R: (0,0)→(0,1)→(0,2)→(1,2)→(1,1)
        //   G R R B B       B: (0,3)→(0,4)→(1,4)→(1,3)→(2,3)
        //   G G G B Y       G: (1,0)→(2,0)→(2,1)→(2,2)→(3,2)
        //   O O G Y Y       Y: (2,4)→(3,4)→(3,3)→(4,3)→(4,4)
        //   O O O Y Y       O: (4,2)→(4,1)→(4,0)→(3,0)→(3,1)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  1, 1),
            pair(.blue,   0, 3,  2, 3),
            pair(.green,  1, 0,  3, 2),
            pair(.yellow, 2, 4,  4, 4),
            pair(.orange, 4, 2,  3, 1),
        ]),

        // -------------------------------------------------------
        // P5  (Medium — long reach)
        // Solution:
        //   R R R R B       R: (0,0)→(0,1)→(0,2)→(0,3)→(1,3)
        //   G G G R B       B: (0,4)→(1,4)→(2,4)→(2,3)→(2,2)
        //   G G B B B       G: (1,0)→(2,0)→(2,1)→(1,1)→(1,2)
        //   Y Y Y Y Y       Y: (3,0)→(3,1)→(3,2)→(3,3)→(3,4)
        //   O O O O O       O: (4,0)→(4,1)→(4,2)→(4,3)→(4,4)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  1, 3),
            pair(.blue,   0, 4,  2, 2),
            pair(.green,  1, 0,  1, 2),
            pair(.yellow, 3, 0,  3, 4),
            pair(.orange, 4, 0,  4, 4),
        ]),

        // -------------------------------------------------------
        // P6  (Hard — columns & wraps)
        // Solution:
        //   R G G Y B       R: (0,0)→(1,0)→(2,0)→(3,0)→(4,0)
        //   R G G Y B       (column 0)
        //   R G Y Y B       G: (0,1)→(0,2)→(1,2)→(1,1)→(2,1)
        //   R O Y O B       Y: (0,3)→(1,3)→(2,3)→(2,2)→(3,2)
        //   R O O O B       O: (3,1)→(4,1)→(4,2)→(4,3)→(3,3)
        //                   B: (0,4)→(1,4)→(2,4)→(3,4)→(4,4)
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  4, 0),
            pair(.blue,   0, 4,  4, 4),
            pair(.green,  0, 1,  2, 1),
            pair(.yellow, 0, 3,  3, 2),
            pair(.orange, 3, 1,  3, 3),
        ]),

        // -------------------------------------------------------
        // P7  (Hard — mixed lengths)
        // Solution:
        //   R R R R R R     R: (0,0)→(0,1)→(0,2)→(0,3)→(0,4)→(1,4)
        //   B B G G R       (6 cells)
        //   B B Y G G       B: (1,0)→(1,1)→(2,0)→(2,1)  (wait, not adj)
        //
        // Let me redo P7 carefully:
        //   R R R R R       R: (0,0)→(0,1)→(0,2)→(0,3)→(0,4)→(1,4)
        //   B B G G R       B: (1,0)→(1,1)→(2,1)→(2,0)  (4 cells)
        //   B B Y G G       G: (1,2)→(1,3)→(2,3)→(2,4)→(3,4)→(3,3) (6)
        //   Y Y Y G G       Y: (2,2)→(3,2)→(3,1)→(3,0)  (4 cells)
        //   O O O O O       O: (4,0)→(4,1)→(4,2)→(4,3)→(4,4) (5)
        //   Total: 6+4+6+4+5 = 25 ✓
        //
        // adj checks:
        // R: all horiz then (0,4)→(1,4) ✓
        // B: (1,0)→(1,1) ✓ (1,1)→(2,1) ✓ (2,1)→(2,0) ✓
        // G: (1,2)→(1,3) ✓ (1,3)→(2,3) ✓ (2,3)→(2,4) ✓ (2,4)→(3,4) ✓ (3,4)→(3,3) ✓
        // Y: (2,2)→(3,2) ✓ (3,2)→(3,1) ✓ (3,1)→(3,0) ✓
        // O: all horiz ✓
        // -------------------------------------------------------
        PipePuzzle(size: 5, pairs: [
            pair(.red,    0, 0,  1, 4),
            pair(.blue,   1, 0,  2, 0),
            pair(.green,  1, 2,  3, 3),
            pair(.yellow, 2, 2,  3, 0),
            pair(.orange, 4, 0,  4, 4),
        ]),
    ]
}

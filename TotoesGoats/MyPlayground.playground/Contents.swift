//: Playground - noun: a place where people can play

import UIKit

for frameNo in 0 ... 120 {
    var blueValue = (1.0 + sin(Double(frameNo) / 10.0)) * 0.5 * 255
    print(blueValue)
}
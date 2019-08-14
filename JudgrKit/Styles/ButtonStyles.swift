//
//  ButtonStyles.swift
//  Judgr
//
//  Created by Willis Plummer on 8/1/19.
//  Copyright © 2019 Willis Plummer. All rights reserved.
//

import Foundation
import UIKit

func set<Root, Value>(_ kp: ReferenceWritableKeyPath<Root, Value>, _ value: Value) -> (Root) -> Void {
    return { root in
        root[keyPath: kp] = value
    }
}

let buttonTitleStyle: (UIButton) -> Void = { $0.setTitleColor(.red, for: .normal) }
let buttonStyle =
    buttonTitleStyle
        <> set(\.backgroundColor, .black)

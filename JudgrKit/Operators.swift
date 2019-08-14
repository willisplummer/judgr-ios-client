//
//  Operators.swift
//  Judgr
//
//  Created by Willis Plummer on 8/1/19.
//  Copyright © 2019 Willis Plummer. All rights reserved.
//

import Foundation

precedencegroup ForwardApplication {
    associativity: left
}

infix operator |>: ForwardApplication

public func |> <A, B>(x: A, f: (A) -> B) -> B {
    return f(x)
}

precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator >>>: ForwardComposition

public func >>> <A, B, C>(
    f: @escaping (A) -> B,
    g: @escaping (B) -> C
    ) -> ((A) -> C) {
    
    return { g(f($0)) }
}

precedencegroup SingleTypeComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator <>: SingleTypeComposition

public func <> <A>(
    f: @escaping (A) -> A,
    g: @escaping (A) -> A)
    -> ((A) -> A) {
        return f >>> g
}

public func |> <A: AnyObject>(x: A, f: (A) -> Void) -> A {
    f(x)
    return x
}

public func <> <A: AnyObject>(
    f: @escaping (A) -> Void,
    g: @escaping (A) -> Void)
    -> (A) -> Void {
        return { a in
            f(a)
            g(a)
        }
}


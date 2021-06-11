//
//  RxSkeleton.swift
//  RxSkeleton
//
//  Created by Archer on 2018/12/1.
//

import Foundation

enum RxSkeletonError: Error {
    case castingError(object: Any, targetType: Any.Type)
}

internal func debugFatalError(_ e: Error) {
    #if DEBUG
    fatalError("\(e)")
    #else
    print("\(e)")
    #endif
}

func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
    guard let returnValue = object as? T else {
        throw RxSkeletonError.castingError(object: object, targetType: resultType)
    }

    return returnValue
}

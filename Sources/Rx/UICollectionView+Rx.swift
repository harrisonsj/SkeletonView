//
//  UICollectionView+Rx.swift
//  RxSkeleton
//
//  Created by Archer on 2018/11/30.
//

import UIKit
import RxSwift
import RxCocoa
import SkeletonView
import RxDataSources

extension Reactive where Base: UICollectionView {
    /**
     Binds sequences of elements to collection view items using a custom reactive data used to perform the transformation.
     
     - parameter dataSource: Data source used to transform elements to view cells.
     - parameter source: Observable sequence of items.
     - returns: Disposable object that can be used to unbind.
     
     Example
     
     let dataSource = RxCollectionViewSectionedReloadDataSource<SectionModel<String, Double>>()
     
     let items = Observable.just([
     SectionModel(model: "First section", items: [
     1.0,
     2.0,
     3.0
     ]),
     SectionModel(model: "Second section", items: [
     1.0,
     2.0,
     3.0
     ]),
     SectionModel(model: "Third section", items: [
     1.0,
     2.0,
     3.0
     ])
     ])
     
     dataSource.configureCell = { (dataSource, cv, indexPath, element) in
     let cell = cv.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! NumberCell
     cell.value?.text = "\(element) @ row \(indexPath.row)"
     return cell
     }
     
     items
     .bind(to: collectionView.rx.items(dataSource: dataSource))
     .disposed(by: disposeBag)
     */
    public func items<
        DataSource: RxCollectionViewDataSourceType & SkeletonCollectionViewDataSource,
        O: ObservableType>
        (dataSource: DataSource)
        -> (_ source: O)
        -> Disposable where DataSource.Element == O.Element
    {
        return { source in
            // This is called for sideeffects only, and to make sure delegate proxy is in place when
            // data source is being bound.
            // This is needed because theoretically the data source subscription itself might
            // call `self.rx.delegate`. If that happens, it might cause weird side effects since
            // setting data source will set delegate, and UICollectionView might get into a weird state.
            // Therefore it's better to set delegate proxy first, just to be sure.
            _ = self.delegate
            // Strong reference is needed because data source is in use until result subscription is disposed
            return source.subscribeProxyDataSource(ofObject: self.base, dataSource: dataSource, retainDataSource: true) { [weak collectionView = self.base] (_: RxCollectionViewSkeletonedDataSourceProxy, event) -> Void in
                guard let collectionView = collectionView else {
                    return
                }
                dataSource.collectionView(collectionView, observedEvent: event)
            }
        }
    }

    public var skeletonedDataSource: DelegateProxy<UICollectionView, SkeletonCollectionViewDataSource> {
        RxCollectionViewSkeletonedDataSourceProxy.proxy(for: base)
    }

    /// Reactive wrapper for `delegate` message `collectionView(_:didSelectItemAtIndexPath:)`.
    ///
    /// It can be only used when one of the `rx.itemsWith*` methods is used to bind observable sequence,
    /// or any other data source conforming to `SectionedViewDataSourceType` protocol.
    ///
    /// ```
    ///     collectionView.rx.modelSelected(MyModel.self)
    ///        .map { ...
    /// ```
    public func skeletonedModelSelected<T>(_ modelType: T.Type) -> ControlEvent<T> {
        let source: Observable<T> = itemSelected.flatMap { [weak view = self.base as UICollectionView] indexPath -> Observable<T> in
            guard let view = view else {
                return Observable.empty()
            }

            return Observable.just(try view.rx.skeletonedModel(at: indexPath))
        }

        return ControlEvent(events: source)
    }

    /// Reactive wrapper for `delegate` message `collectionView(_:didSelectItemAtIndexPath:)`.
    ///
    /// It can be only used when one of the `rx.itemsWith*` methods is used to bind observable sequence,
    /// or any other data source conforming to `SectionedViewDataSourceType` protocol.
    ///
    /// ```
    ///     collectionView.rx.modelDeselected(MyModel.self)
    ///        .map { ...
    /// ```
    public func skeletonedModelDeselected<T>(_ modelType: T.Type) -> ControlEvent<T> {
        let source: Observable<T> = itemDeselected.flatMap { [weak view = self.base as UICollectionView] indexPath -> Observable<T> in
            guard let view = view else {
                return Observable.empty()
            }

            return Observable.just(try view.rx.skeletonedModel(at: indexPath))
        }

        return ControlEvent(events: source)
    }

    /// Synchronous helper method for retrieving a model at indexPath through a reactive data source
    public func skeletonedModel<T>(at indexPath: IndexPath) throws -> T {
        guard let dataSource = self.skeletonedDataSource.forwardToDelegate() as? SectionedViewDataSourceType else {
            throw RxSkeletonError.castingError(object: self.skeletonedDataSource.forwardToDelegate(), targetType: SectionedViewDataSourceType.self)
            //fatalError("This method only works in case one of the `rx.itemsWith*` methods was used.")
        }

        let element = try dataSource.model(at: indexPath)

        
        return try castOrThrow(T.self, element)
    }
}


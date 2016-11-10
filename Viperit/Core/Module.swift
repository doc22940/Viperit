//
//  Module.swift
//  Viperit
//
//  Created by Ferran on 11/09/2016.
//  Copyright © 2016 Ferran Abelló. All rights reserved.
//

import Foundation
import UIKit

private let kTabletSuffix = "Pad"

//MARK: - Viperit Module Protocol
public protocol ViperitModule {
    var storyboardName: String { get }
}

public extension RawRepresentable where Self: ViperitModule, RawValue == String {
    var storyboardName: String {
        return rawValue
    }
}

//MARK: - Module
public struct Module {
    public fileprivate(set) var view: UserInterface!
    public fileprivate(set) var interactor: Interactor!
    public fileprivate(set) var presenter: Presenter!
    public fileprivate(set) var router: Router!
    public fileprivate(set) var displayData: DisplayData!
    
    public static func build<T: RawRepresentable & ViperitModule>(_ module: T, bundle: Bundle = Bundle.main) -> Module where T.RawValue == String {
        //Get class types
        let interactorClass = module.classForViperComponent(.interactor, bundle: bundle) as! Interactor.Type
        let presenterClass = module.classForViperComponent(.presenter, bundle: bundle) as! Presenter.Type
        let routerClass = module.classForViperComponent(.router, bundle: bundle) as! Router.Type
        let displayDataClass = module.classForViperComponent(.displayData, bundle: bundle) as! DisplayData.Type

        //Allocate VIPER components
        let V = loadView(forModule: module, bundle: bundle)
        let I = interactorClass.init()
        let P = presenterClass.init()
        let R = routerClass.init()
        let D = displayDataClass.init()
        
        return build(view: V, interactor: I, presenter: P, router: R, displayData: D)
    }
}

//MARK: - Inject Mock View for Testing
public extension Module {

    public mutating func injectMock(view mockView: UserInterface) {
        view = mockView
        view._presenter = presenter
        presenter._view = view
    }
}


//MARK: - Helper Methods
fileprivate extension Module {
    
    fileprivate static func loadView<T: RawRepresentable & ViperitModule>(forModule module: T, bundle: Bundle) -> UserInterface where T.RawValue == String {
        let viewClass = module.classForViperComponent(.view, bundle: bundle) as! UIViewController.Type
        let sb = UIStoryboard(name: module.storyboardName.capitalized, bundle: bundle)
        let viewIdentifier = NSStringFromClass(viewClass).components(separatedBy: ".").last! as String
        let viewObject = sb.instantiateViewController(withIdentifier: viewIdentifier) as! UserInterface
        return viewObject
    }
    
    fileprivate static func build(view: UserInterface, interactor: Interactor, presenter: Presenter, router: Router, displayData: DisplayData) -> Module {
        //View connections
        view._presenter = presenter
        view._displayData = displayData
        
        //Interactor connections
        interactor._presenter = presenter
        
        //Presenter connections
        presenter._router = router
        presenter._interactor = interactor
        presenter._view = view
        
        //Router connections
        router._presenter = presenter
        
        return Module(view: view, interactor: interactor, presenter: presenter, router: router, displayData: displayData)
    }
}


//MARK: - Private Extension for Application Module generic enum
fileprivate extension RawRepresentable where RawValue == String {
    
    private func classStringForComponent(_ component: ViperComponent) -> String {
        let classString = component.rawValue
        let uppercasedClassString = String(classString.characters.prefix(1)).uppercased() + String(classString.characters.dropFirst())
        return rawValue.capitalized + uppercasedClassString
    }
    
    fileprivate func classForViperComponent(_ component: ViperComponent, bundle: Bundle) -> Swift.AnyClass? {
        let className = classStringForComponent(component)
        let bundleName = bundle.infoDictionary!["CFBundleName"] as! String
        let classInBundle = (bundleName + "." + className).replacingOccurrences(of: " ", with: "_")
        
        if component == .view {
            let isPad = UIScreen.main.traitCollection.userInterfaceIdiom == .pad
            if isPad {
                if let tabletView = NSClassFromString(classInBundle + kTabletSuffix) {
                    return tabletView
                }
            }
        }
        
        return NSClassFromString(classInBundle)
    }
}
//
//  TagProductsCollectionViewController.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import UIKit
import CoreNFC
import CoreData

class TagProductsCollectionViewContoller : UIViewController {
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: UICollectionView!
    
    internal var tagReaderSession: NFCTagReaderSession?
    
    var tagWallet: TagWallet?
    var searchController: UISearchController!
    
    var productTagType: String? = "Figure"
    var filteredTagProductGroups: [(gameSeries: String, tagProducts: [TagProduct])] = []
    
    @IBAction func productTagTypeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
            case 0: productTagType = "Figure"
            case 1: productTagType = "Card"
            default: productTagType = nil
        }
        NSLog("TagProduct type changed!")
        updateFilteredTagProducts()
    }

    var tagWalletURL: URL {
        let documentsDirectory: URL = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("tagWallet.json")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                                
        setupSearchController()
        loadTagWallet()
    }
    
    
    func loadTagWallet() {
        // Copy the built-in tagWallet.json file from bundle to documents folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: tagWalletURL.path), let builtInDataURL = Bundle.main.url(forResource: "tagWallet", withExtension: "json") {
            do {
                try FileManager.default.copyItem(at: builtInDataURL, to: tagWalletURL)
            } catch let error {
                NSLog("Error copying built in data to tagProducts.json: \(error)")
                return
            }
        }
        do {
            let data = try Data(contentsOf: tagWalletURL)
            tagWallet = try JSONDecoder().decode(TagWallet.self, from: data)
            updateFilteredTagProducts()
        } catch let error {
            NSLog("Error loading tagProducts.json: \(error)")
            tagWallet = TagWallet(tagProducts: [], staticKey: nil, dataKey: nil)
            return
            
        }
    }
    func saveTagWallet() {
        do {
            let tagWalletData = try JSONEncoder().encode(tagWallet)
            try tagWalletData.write(to: tagWalletURL)
            NSLog("DONE: \(tagWalletURL)")
        } catch let error {
            NSLog("Error writing tagWallet.json: \(error)")
            return
        }
    }
    
    func setupSearchController() {
        self.definesPresentationContext = true
        searchController = UISearchController(searchResultsController: nil)
        searchController.definesPresentationContext = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        headerView.addSubview(searchController.searchBar)
        headerViewHeightConstraint.constant = searchController.searchBar.frame.height
    }
    
    func updateFilteredTagProducts() {
        var filteredTagProducts = tagWallet?.tagProducts ?? []
        if let type = productTagType {
            filteredTagProducts = filteredTagProducts.filter { $0.type == type }
        }
        if let search = searchController.searchBar.text?.lowercased(), search != "" {
            filteredTagProducts = filteredTagProducts.filter { $0.productSeries.lowercased().contains(search) || $0.gameSeries.lowercased().contains(search) || $0.name.lowercased().contains(search) }
        }
        filteredTagProductGroups = Dictionary(grouping: filteredTagProducts, by: { $0.productSeries }).map({ $0 }).sorted(by: { (a, b) -> Bool in
            a.gameSeries < b.gameSeries
        })
        self.collectionView.reloadData()
    }
    
    func showTagProduct(_ tagProduct: TagProduct, newDump: TagDump? = nil) {
        guard let navVC = storyboard?.instantiateViewController(identifier: "TagProductNavViewController") as? UINavigationController,
            let tagProductVC = navVC.topViewController as? TagProductViewController else {
            return
        }
        tagProductVC.tagProduct = tagProduct
        tagProductVC.newlyReadDump = newDump
        tagProductVC.tagProductsCollectionViewContoller = self
        searchController.searchBar.endEditing(true)
        present(navVC, animated: true, completion: nil)
    }
}
extension TagProductsCollectionViewContoller : UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        updateFilteredTagProducts()
    }
}
extension TagProductsCollectionViewContoller : UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return filteredTagProductGroups.count
    }
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header", for: indexPath) as! TagProductsHeaderView
        header.gameSeriesLabel.text = filteredTagProductGroups[indexPath.section].gameSeries
        
        return header
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredTagProductGroups[section].tagProducts.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagProduct", for: indexPath) as! TagProductCollectionViewCell
        cell.tagProduct = filteredTagProductGroups[indexPath.section].tagProducts[indexPath.row]
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showTagProduct(filteredTagProductGroups[indexPath.section].tagProducts[indexPath.row])
    }
    
    
}
extension TagProductsCollectionViewContoller : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 114, height: 190)
    }
}

class TagProductsHeaderView : UICollectionReusableView {
    @IBOutlet weak var gameSeriesLabel: UILabel!
}

class TagProductCollectionViewCell : UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var nameLabel: UILabel!
    
    var tagProduct: TagProduct! {
        didSet {
            nameLabel.text = tagProduct.name
            tagProduct.getImage { self.imageView.image = $0 }
        }
    }
    
}

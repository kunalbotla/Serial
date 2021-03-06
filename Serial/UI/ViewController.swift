//
//  ViewController.swift
//  Serial
//
//  Created by Ayden Panhuyzen on 2019-04-04.
//  Copyright © 2019 Ayden Panhuyzen. All rights reserved.
//

import UIKit
import SerialKit

class ViewController: ThemedTableViewController {
    var manualEntryToolbar: UIToolbar!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Listen for history change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(reloadHistory), name: HistoryManager.notification, object: nil)
        
        // Create toolbar to show in manual entry keyboard
        manualEntryToolbar = UIToolbar()
        manualEntryToolbar.items = [
            UIBarButtonItem(title: "Scan Barcode", style: .plain, target: self, action: #selector(showCamera)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissTextField))
        ]
        
        // Only show large title on iOS 13+ (new blended navigation bar mode looks great, the large + tint does not.)
        if #available(iOS 13.0, *) {
            navigationItem.largeTitleDisplayMode = .always
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textField?.text = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField?.becomeFirstResponder()
    }
    
    @objc func analyzeManualEntry() {
        guard let text = textField?.text, SerialAnalysis.isValid(serialNumber: text) else {
            showAlert(title: "Enter a Serial Number", message: "Please enter a valid 12-digit serial number in order to start analysis.")
            return
        }
        ResultsViewController.presentAnalysis(for: text, onViewController: self)
    }
    
    private weak var textField: UITextField? {
        didSet {
            textField?.addTarget(self, action: #selector(analyzeManualEntry), for: .editingDidEndOnExit)
            textField?.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
            manualEntryToolbar.sizeToFit()
            textField?.inputAccessoryView = manualEntryToolbar
        }
    }
    
    // MARK: - History Loading
    
    private var history = Array(HistoryManager.shared.items.reversed()) {
        didSet { tableView.reloadSections(IndexSet(integer: 1), with: .fade) }
    }
    
    @objc func reloadHistory() {
        history = HistoryManager.shared.items.reversed()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2
        case 1: return history.count
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SerialEntry") as! TextFieldCell
                textField = cell.textField
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Button") as! ButtonCell
                cell.button.setTitle("Analyze", for: .normal)
                return cell
            default: fatalError("Unknown row.")
            }
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryItem") as! HistoryItemCell
            cell.item = history[indexPath.row]
            return cell
        default: fatalError("Unknown section.")
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Manual Entry"
        case 1: return "History"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1 else { return nil }
        return history.isEmpty ? "No previous analyses." : nil
    }
    
    // MARK: - UITableView Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 { analyzeManualEntry(); return }
            textField?.becomeFirstResponder()
        case 1: ResultsViewController.presentAnalysis(for: history[indexPath.row].serialNumber, onViewController: self)
        default: break
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard indexPath.section == 1, editingStyle == .delete else { return }
        HistoryManager.shared.deleteAll(serialNumber: history[indexPath.row].serialNumber)
    }
    
    // MARK: History Previews
    
    private var previewingAnalysis: SerialAnalysis?
    @available(iOS 13.0, *)
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let analysis = SerialAnalysis(serialNumber: history[indexPath.row].serialNumber) else { return nil }
        
        // Store in a variable to use for the tap action
        previewingAnalysis = analysis
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: { ResultsViewController(analysis: analysis) }, actionProvider: nil)
    }
    
    @available(iOS 13.0, *)
    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let analysis = previewingAnalysis else { return }
        animator.addCompletion {
            ResultsViewController.present(analysis: analysis, onViewController: self)
        }
        previewingAnalysis = nil
    }
    
    // MARK: - UITextField actions
    
    @objc func valueChanged() {
        tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
    }
    
    @objc func showCamera() {
        performSegue(withIdentifier: "ShowCamera", sender: nil)
    }
    
    @objc func dismissTextField() {
        textField?.resignFirstResponder()
    }
    
}

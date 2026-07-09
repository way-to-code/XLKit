//
//  TabSelectionTests.swift
//  XLKit • https://github.com/TheAcharya/XLKit
//  © 2025 Vigneswaran Rajkumar • Licensed under MIT License
//

import XCTest
import ZIPFoundation
@testable import XLKit
@testable import XLKitXLSX

/// `tabSelected="1"` may only be emitted for the active sheet. When several worksheets carry the
/// flag, Excel for Windows opens the workbook with those sheets grouped, and editing is blocked
/// as soon as a protected sheet is part of the group.
@MainActor
final class TabSelectionTests: XLKitTestBase {

    func testActiveSheetIndexDefaultsToFirstSheet() {
        let workbook = Workbook()
        _ = workbook.addSheet(name: "Main")
        _ = workbook.addSheet(name: "Strings")
        XCTAssertEqual(XLSXEngine.activeSheetIndex(for: workbook.getSheets()), 0)
    }

    func testActiveSheetIndexSkipsHiddenSheets() {
        let workbook = Workbook()
        let first = workbook.addSheet(name: "Hidden1")
        let second = workbook.addSheet(name: "Hidden2")
        _ = workbook.addSheet(name: "Visible")
        first.state = .hidden
        second.state = .veryHidden
        XCTAssertEqual(XLSXEngine.activeSheetIndex(for: workbook.getSheets()), 2)
    }

    func testActiveSheetIndexFallsBackToZeroWhenAllHidden() {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Hidden")
        sheet.state = .hidden
        XCTAssertEqual(XLSXEngine.activeSheetIndex(for: workbook.getSheets()), 0)
    }

    func testActiveSheetViewEmitsTabSelected() {
        XCTAssertEqual(
            XLSXEngine.sheetViewXML(isActive: true),
            "<sheetView tabSelected=\"1\" workbookViewId=\"0\"/>"
        )
    }

    func testInactiveSheetViewOmitsTabSelected() {
        XCTAssertEqual(
            XLSXEngine.sheetViewXML(isActive: false),
            "<sheetView workbookViewId=\"0\"/>"
        )
    }

    func testSavedWorkbookMarksOnlyFirstSheetSelected() throws {
        let workbook = Workbook()
        workbook.addSheet(name: "Main").setCell("A1", value: .string("Main"))
        let strings = workbook.addSheet(name: "Strings")
        strings.setCell("A1", value: .string("Strings"))
        strings.state = .hidden
        strings.protection = SheetProtection()

        let worksheets = try savedWorksheetsXML(workbook: workbook, prefix: "tab_selected", count: 2)
        XCTAssertTrue(worksheets[0].contains("tabSelected=\"1\""))
        XCTAssertFalse(worksheets[1].contains("tabSelected"))
    }

    func testSavedWorkbookMarksFirstVisibleSheetSelectedWhenFirstIsHidden() throws {
        let workbook = Workbook()
        let hidden = workbook.addSheet(name: "Strings")
        hidden.setCell("A1", value: .string("Strings"))
        hidden.state = .hidden
        workbook.addSheet(name: "Main").setCell("A1", value: .string("Main"))

        let worksheets = try savedWorksheetsXML(workbook: workbook, prefix: "tab_selected_hidden_first", count: 2)
        XCTAssertFalse(worksheets[0].contains("tabSelected"))
        XCTAssertTrue(worksheets[1].contains("tabSelected=\"1\""))
    }

    /// Saves the workbook to a temporary file and returns the XML of `xl/worksheets/sheet<N>.xml`
    /// for sheets 1...count, in sheet-id order.
    private func savedWorksheetsXML(workbook: Workbook, prefix: String, count: Int) throws -> [String] {
        let url = makeTempWorkbookURL(prefix: prefix)
        defer { cleanupTempFile(at: url) }
        try workbook.save(to: url)

        let archive = try Archive(url: url, accessMode: .read)
        return try (1...count).map { index in
            let path = "xl/worksheets/sheet\(index).xml"
            guard let entry = archive[path] else {
                XCTFail("Missing \(path) in generated workbook")
                return ""
            }
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            return String(decoding: data, as: UTF8.self)
        }
    }
}

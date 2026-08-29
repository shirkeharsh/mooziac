import Foundation
import SQLite3

public struct SQLiteTableStats: Identifiable {
    public var id: String { name }
    public let name: String
    public let rowCount: Int
    public let columns: [String]
}

public struct SQLiteRecordRow: Identifiable {
    public let id = UUID()
    public let columns: [String]
    public let values: [String: String]
    
    public init(columns: [String] = [], values: [String: String] = [:]) {
        self.columns = columns
        self.values = values
    }
}

public final class SQLiteInspector {
    public static let shared = SQLiteInspector()
    
    public var dbPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let mooziacDir = appSupport.appendingPathComponent("Mooziac")
        
        let libraryPath = mooziacDir.appendingPathComponent("library.sqlite3").path
        if FileManager.default.fileExists(atPath: libraryPath) {
            return libraryPath
        }
        
        let fallbackPath = mooziacDir.appendingPathComponent("mooziac.db").path
        if FileManager.default.fileExists(atPath: fallbackPath) {
            return fallbackPath
        }
        
        return libraryPath
    }
    
    public var dbFileName: String {
        URL(fileURLWithPath: dbPath).lastPathComponent
    }
    
    public var dbFileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
              let size = attrs[.size] as? Int64 else {
            return "0 KB"
        }
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576.0)
        } else {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        }
    }
    
    public var isDatabaseAvailable: Bool {
        FileManager.default.fileExists(atPath: dbPath)
    }
    
    public func fetchTableStats() -> [SQLiteTableStats] {
        guard isDatabaseAvailable else { return [] }
        
        var db: OpaquePointer?
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        var rc = sqlite3_open_v2(dbPath, &db, openFlags, nil)
        if rc != SQLITE_OK {
            rc = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
            if rc != SQLITE_OK {
                return []
            }
        }
        defer { sqlite3_close(db) }
        
        var stmtTimeout: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA busy_timeout = 3000;", -1, &stmtTimeout, nil) == SQLITE_OK {
            sqlite3_step(stmtTimeout)
        }
        sqlite3_finalize(stmtTimeout)
        
        var tableNames: [String] = []
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC;"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cName = sqlite3_column_text(stmt, 0) {
                    tableNames.append(String(cString: cName))
                }
            }
        }
        sqlite3_finalize(stmt)
        
        var stats: [SQLiteTableStats] = []
        for name in tableNames {
            var count = 0
            let countQuery = "SELECT COUNT(*) FROM \"\(name)\";"
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                if sqlite3_step(countStmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(countStmt, 0))
                }
            }
            sqlite3_finalize(countStmt)
            
            var cols: [String] = []
            let pragma = "PRAGMA table_info(\"\(name)\");"
            var pragmaStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, pragma, -1, &pragmaStmt, nil) == SQLITE_OK {
                while sqlite3_step(pragmaStmt) == SQLITE_ROW {
                    if let colName = sqlite3_column_text(pragmaStmt, 1) {
                        cols.append(String(cString: colName))
                    }
                }
            }
            sqlite3_finalize(pragmaStmt)
            
            stats.append(SQLiteTableStats(name: name, rowCount: count, columns: cols))
        }
        
        return stats
    }
    
    public func fetchSampleRows(from tableName: String, limit: Int = 50) -> [SQLiteRecordRow] {
        guard isDatabaseAvailable else { return [] }
        
        var db: OpaquePointer?
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        var rc = sqlite3_open_v2(dbPath, &db, openFlags, nil)
        if rc != SQLITE_OK {
            rc = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
            if rc != SQLITE_OK {
                return []
            }
        }
        defer { sqlite3_close(db) }
        
        var stmtTimeout: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA busy_timeout = 3000;", -1, &stmtTimeout, nil) == SQLITE_OK {
            sqlite3_step(stmtTimeout)
        }
        sqlite3_finalize(stmtTimeout)
        
        var tableCols: [String] = []
        let pragma = "PRAGMA table_info(\"\(tableName)\");"
        var pragmaStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, pragma, -1, &pragmaStmt, nil) == SQLITE_OK {
            while sqlite3_step(pragmaStmt) == SQLITE_ROW {
                if let colName = sqlite3_column_text(pragmaStmt, 1) {
                    tableCols.append(String(cString: colName))
                }
            }
        }
        sqlite3_finalize(pragmaStmt)
        
        let query = "SELECT * FROM \"\(tableName)\" LIMIT \(limit);"
        var stmt: OpaquePointer?
        var rows: [SQLiteRecordRow] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            let colCount = sqlite3_column_count(stmt)
            var colNames: [String] = []
            for i in 0..<colCount {
                if let name = sqlite3_column_name(stmt, i) {
                    colNames.append(String(cString: name))
                } else {
                    colNames.append("col_\(i)")
                }
            }
            if tableCols.isEmpty {
                tableCols = colNames
            }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                var rowMap: [String: String] = [:]
                for i in 0..<colCount {
                    let colName = colNames[Int(i)]
                    if let valText = sqlite3_column_text(stmt, i) {
                        rowMap[colName] = String(cString: valText)
                    } else {
                        rowMap[colName] = "NULL"
                    }
                }
                rows.append(SQLiteRecordRow(columns: tableCols, values: rowMap))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }
}

//
//  ContentView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select an item")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Clipboard Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("No text on clipboard", text: Binding(
                        get: { clipboardManager.currentText ?? "" },
                        set: { _ in }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Is API Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: Binding(
                        get: { String(clipboardManager.isAPIKey) },
                        set: { _ in }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                }
            }
            .padding()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environmentObject(ClipboardManager())
}

//
//  LanguagePicker.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

/// A picker control for selecting the preferred programming language.
struct LanguagePicker: View {
    @Environment(DocumentationViewModel.self) var documentationViewModel
    /// The list of available variants containing language information.
    let variants: [Variant]
    
    /// Filters the available languages from the variants.
    var filteredLanguages: [PreferedProgrammingLanguage] {
        let traits = variants.flatMap({ $0.traits })
        let languages = traits.compactMap({ $0.interfaceLanguage })
        
        return languages
    }
    
    var body: some View {
        if filteredLanguages.count == 1 && filteredLanguages[0].humanReadable == nil {
            EmptyView()
        } else {
            @Bindable var documentationViewModel = documentationViewModel
            Picker("Language: ", selection: $documentationViewModel.preferedProgrammingLanguage) {
                if filteredLanguages.count == 1 {
                    if let humanReadable = filteredLanguages[0].humanReadable {
                        Text(humanReadable)
                            .tag(documentationViewModel.preferedProgrammingLanguage)
                    }
                } else {
                    ForEach(filteredLanguages, id: \.self) { language in
                        if let humanReadable = language.humanReadable {
                            Text(humanReadable)
                                .tag(language)
                        }
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

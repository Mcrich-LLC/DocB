//
//  LanguagePicker.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/13/24.
//

import SwiftUI

struct LanguagePicker: View {
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let variants: [Variant]
    
    var filteredLanguages: [PreferedProgrammingLanguage] {
        let traits = variants.flatMap({ $0.traits })
        let languages = traits.compactMap({ $0.interfaceLanguage })
        
        return languages
    }
    
    var body: some View {
        Picker("Language: ", selection: $documentationViewModel.preferedProgrammingLanguage) {
            if filteredLanguages.count == 1 {
                Text(filteredLanguages[0].humanReadable)
                    .tag(documentationViewModel.preferedProgrammingLanguage)
            } else {
                ForEach(filteredLanguages, id: \.self) { language in
                    Text(language.humanReadable)
                        .tag(language)
                }
            }
        }
    }
}

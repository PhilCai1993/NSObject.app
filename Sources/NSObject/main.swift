import Foundation
import Publish
import Plot
import CNAMEPublishPlugin


// This type acts as the configuration for your website.
struct NSObject: Website {
    enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case posts
    }

    struct ItemMetadata: WebsiteItemMetadata {
        // Add any site-specific metadata that you want to use here.
    }

    // Update these properties to configure your website:
    var url = URL(string: "https://nsobject.app")!
    var name = "NSObject.app"
    var description = ""
    var language: Language { .chinese }
    var imagePath: Path? { nil }
}

// This will generate your website using the built-in Foundation theme:
try NSObject().publish(withTheme: .foundation,
                       deployedUsing: .gitHub("PhilCai1993/PhilCai1993.github.io"),
                       plugins: [.addCNAME()])
//try NSObject().publish(using: [
//
//    .installPlugin(.addCNAME()),
//    .generateHTML(withTheme: .foundation),
//    .deploy(using: .gitHub("PhilCai1993/PhilCai1993.github.io")),
//
//])

//
//  HtmlTextView.swift
//  HtmlTextView
//
//  Created by 黄建斌 on 2024/6/17.
//

import Foundation
import SwiftUI
import SwiftSoup
import Shimmer

typealias Style = Font

indirect enum ViewRender {
    static let VERTICLE = 0
    static let HORIZONTAL = 1
    static let NONE = -1
    
    case root(children: [ViewRender])
    case text(contents: [TextContents])
    case container(orientation: Int, children: [ViewRender])
    case img(src: String)
    case li(children: [ViewRender])
    case empty
    
    static func + (_ a: ViewRender, _ b: ViewRender) -> ViewRender? {
        switch (a, b) {
        case let (.text(lcontents), .text(rcontents)):
            var contents: [TextContents] = []
            for view in lcontents {
                contents.append(view)
            }
            for view in rcontents {
                contents.append(view)
            }
            return .text(contents: contents)
        default:
            return nil
        }
    }
}

struct NodeView: View {
    
//    @Environment(\.openURL) private var openURL
    private var viewRender: ViewRender
    
    init(_ viewRender: ViewRender) {
        self.viewRender = viewRender
    }
    
    var body: some View {
        switch viewRender {
        case .root(children: let children):
            ForEach(0..<children.count, id: \.self) { index in
                NodeView(children[index])
            }
        case .text(contents: let contents):
            contents.map({
                // TODO style
                let content = $0.content
                var attrStr: AttributedString? = nil
                if let link = $0.link, let url = URL(string: link) {
                    attrStr = AttributedString(content)
                    attrStr?.link = url
                    attrStr?.underlineStyle = .single
                }
                var text: Text
                if let attrStr = attrStr {
                    text = Text(attrStr)
                } else {
                    text = Text(content)
                }
                if let font = $0.style {
                    text = text.font(font)
                }
                return text
            }).reduce(Text(""), +).padding(.vertical, 2.5)
        case .img(src: let src):
            AsyncImage(url: URL(string: src)) { phase in
                if let returnImage = phase.image {
                    returnImage.resizable()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .cornerRadius(5.0, antialiased: true)
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .shadow(radius: 5)
                } else {
                    ZStack {
                        Text("Image").foregroundStyle(.secondary.opacity(0.3))
                        Rectangle()
                            .frame(width: 50, height: 50, alignment: .center)
                            .foregroundColor(.primary)
                            .shimmering(gradient: Gradient(colors: [.secondary.opacity(0.3), .secondary, .secondary.opacity(0.3)]), bandSize: 25)
                        
                    }
                }
            }
        case .container(orientation: let ori, children: let children):
            if ori == ViewRender.VERTICLE {
                LazyVStack(alignment: .leading) {
                    ForEach(0..<children.count, id: \.self) { index in
                        NodeView(children[index])
                    }
                }.padding(0)
            } else if ori == ViewRender.HORIZONTAL {
                LazyHStack {
                    ForEach(0..<children.count, id: \.self) { index in
                        NodeView(children[index])
                    }
                }
            } else {
                ForEach(0..<children.count, id: \.self) { index in
                    NodeView(children[index])
                }
            }
        case .li(children: let children):
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(Color.primary).frame(width: 5, height: 5)
                if (children.count <= 1) {
                    ForEach(0..<children.count, id: \.self) { index in
                        NodeView(children[index])
                    }
                } else {
                    VStack {
                        ForEach(0..<children.count, id: \.self) { index in
                            NodeView(children[index])
                        }
                    }
                }
            }
        case .empty:
            EmptyView()
        }
    }
}

struct TextContents {
    var content: String = ""
    var style: Style? = nil
    var link: String? = nil
    
    init(content: String, style: Style?, link: String?) {
        self.content = content
        self.style = style
        self.link = link
    }
}

class Node {
    var tag: String
    var attributes: [String : String] = [:]
    var children: [Node] = []
    var parent: Node? = nil
    
    init(tag: String, attributes: [String : String]) {
        self.tag = tag
        self.attributes = attributes
    }
    
    func toViewRender(style: Style? = nil) -> [ViewRender] {
        // TODO combine styles, maybe we can use array to store?
        let style = style ?? toStyle()
        var viewRender: [ViewRender]
        
        let childViews = Node.renderChildren(children: children, style: style)
        
        if self is TextStyleNode && !(self as! TextStyleNode).newline {
            viewRender = childViews
        } else {
            if childViews.isEmpty {
                NSLog("empty children \(tag)")
                viewRender = []
            } else if childViews.count == 1 {
                viewRender = [.container(orientation: ViewRender.NONE, children: childViews)]
            } else {
                viewRender = [.container(orientation: ViewRender.VERTICLE, children: childViews)]
            }
        }

        return viewRender
    }
    
    static func renderChildren(children: [Node], style: Style? = nil) -> [ViewRender] {
        var childViews: [ViewRender] = []
        for child in children {
            let childViewRenders = child.toViewRender(style: style)
            for childViewRender in childViewRenders {
                if childViews.count > 0 {
                    let lastChild = childViews.removeLast()
                    if let newChild = lastChild + childViewRender {
                        childViews.append(newChild)
                    } else {
                        childViews.append(lastChild)
                        childViews.append(childViewRender)
                    }
                } else {
                    childViews.append(childViewRender)
                }
            }
        }
        return childViews
    }
    
    func toStyle() -> Style? {
        return nil
    }
}

class RootNode: Node {
    func toViewRender() -> [ViewRender] {
        return super.toViewRender(style: nil)
    }
}

class TextStyleNode: Node {
    var font: Style? = nil
    var newline: Bool = false
    
    override func toStyle() -> Style? {
        return font
    }
}

class ContentNode: Node {
    var content: String = ""
    
    init(content: String, attributes: [String: String] = [:]) {
        super.init(tag: "", attributes: attributes)
        self.content = content
    }
    
    override func toViewRender(style: Style? = nil) -> [ViewRender] {
        return [.text(contents: [TextContents(content: self.content, style: style, link: attributes["href"])])]
    }
}

class ImageNode: Node {
    override func toViewRender(style: Style? = nil) -> [ViewRender] {
        return [.img(src: attributes["src"] ?? "")]
    }
}

class IFrameNode: Node {
    override func toViewRender(style: Style? = nil) -> [ViewRender] {
        // TODO
        return [.container(orientation: ViewRender.VERTICLE, children: [.text(contents: [TextContents(content: "This is a frame to be implemented", style: nil, link: nil)])])]
    }
}

class LiNode: Node {
    override func toViewRender(style: Style? = nil) -> [ViewRender] {
        return [.li(children: Node.renderChildren(children: children))]
    }
}

class EmptyNode: Node {
    override func toViewRender(style: Style? = nil) -> [ViewRender] {
        return [.empty]
    }
}

class MyXMLParserDelegate: NSObject, XMLParserDelegate {
    private var curNode: Node? = nil
    var root: RootNode? = nil
    
    let textStyleElements = ["h1", "h2", "h3", "h4", "a", "strong", "em"]
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // fix not closed tag
        if curNode?.tag == elementName {
            NSLog("自动关闭\(elementName)")
            endNode()
        }
        
        NSLog("开始解析元素: \(elementName)(\(attributeDict) \(qName ?? "") \(namespaceURI ?? ""))")
        if root == nil {
            root = RootNode(tag: "root", attributes: [:])
            curNode = root
            NSLog("new root, curNode=root")
        }
        
        let node: Node
        if elementName == "root" {
            node = root ?? RootNode(tag: "root", attributes: [:])
        } else if elementName == "img" {
            NSLog("new img, curNode=img")
            node = ImageNode(tag: elementName, attributes: attributeDict)
        } else if textStyleElements.contains(where: { value in
            value == elementName
        }) == true {
            NSLog("new text style, curNode=style")
            
            // TODO link
            let textStyle  = TextStyleNode(tag: elementName, attributes: attributeDict)
            
            if (elementName == "h1") {
                textStyle.font = .largeTitle
                textStyle.newline = true
            } else if elementName == "h2" {
                textStyle.font = .title
                textStyle.newline = true
            } else if elementName == "h3" {
                textStyle.font = .title2
                textStyle.newline = true
            } else if elementName == "h4" {
                textStyle.font = .title2
                textStyle.newline = true
            } else if elementName == "p" {
                textStyle.newline = true
            }
            
            node = textStyle
        } else if (elementName == "iframe") {
            node = IFrameNode(tag: elementName, attributes: attributeDict)
        } else if (elementName == "li") {
            node = LiNode(tag: elementName, attributes: attributeDict)
        } else if (elementName == "meta") {
            node = EmptyNode(tag: elementName, attributes: attributeDict)
        } else {
            NSLog("new others, curNode=others")
            node = Node(tag: elementName, attributes: attributeDict)
        }
        
        if let cur = curNode, !(node is RootNode){
            node.parent = cur
            cur.children.append(node)
        }
        curNode = node
    }
 
 
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSLog("找到空白字符")
            return
        }
        NSLog("找到字符: \(string)")
        curNode?.children.append(ContentNode(content: string, attributes: curNode?.attributes ?? [:]))
    }
    
   func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
       NSLog("结束解析元素: \(elementName)")
       endNode()
   }
    
    private func endNode() {
        curNode = curNode?.parent
    }
 
    func parserDidEndDocument(_ parser: XMLParser) {
        NSLog("文档解析完成")
    }
    
}

struct HtmlTextView: View {
    private var delegate = MyXMLParserDelegate()
    
    var content: String
    
    init(_ content: String) {
        let html = "<root>\(content)</root>"
        if let body = try?  SwiftSoup.parseBodyFragment(html) {
            body.outputSettings().escapeMode(.xhtml)
            self.content = (try? body.body()?.html()) ?? html
        } else {
            self.content = html
        }
    }
    
    public var renderedTag: some View {
        guard let data = content.data(using: .utf8) else { return NodeView(ViewRender.empty) }
        
        let parser = XMLParser(data: data)
        
        parser.delegate = delegate
        parser.parse()
        let children = delegate.root?.toViewRender()
        
        if let children = children {
            return NodeView(ViewRender.root(children: children))
        } else {
            return NodeView(ViewRender.empty)
        }
    }
    var body: some View {
        renderedTag
    }
}

#Preview {
    ScrollView {
        HtmlTextView(PreviewData.developer2)
    }
}

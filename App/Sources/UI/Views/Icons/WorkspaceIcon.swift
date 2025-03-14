import SwiftUI

struct WorkspaceIcon: View {
  let size: CGFloat
  var body: some View {
    Rectangle()
      .fill(
        LinearGradient(stops: [
          .init(color: Color.blue, location: 0.0),
          .init(color: Color(.cyan), location: 0.6),
          .init(color: Color(.systemPurple.blended(withFraction: 0.6, of: .white)!), location: 1.0),
        ], startPoint: .topLeading, endPoint: .bottom)
      )
      .overlay {
        LinearGradient(stops: [
          .init(color: Color.blue, location: 0.5),
          .init(color: Color(.systemTeal.blended(withFraction: 0.3, of: .white)!), location: 1.0),
        ], startPoint: .topTrailing, endPoint: .bottomTrailing)
        .opacity(0.6)
      }
      .overlay {
        LinearGradient(stops: [
          .init(color: Color(.systemGreen.blended(withFraction: 0.3, of: .white)!), location: 0.2),
          .init(color: Color.clear, location: 0.8),
        ], startPoint: .topTrailing, endPoint: .bottomLeading)
      }
      .overlay { iconOverlay().opacity(0.65) }
      .overlay { iconBorder(size) }
      .overlay {
        WorkspaceIconIllustration(size: size)
      }
      .frame(width: size, height: size)
      .fixedSize()
      .iconShape(size)
  }
}

struct WorkspaceIconIllustration: View {
  let size: CGFloat
  var body: some View {
    let spacing = size * 0.05
    HStack(spacing: spacing) {
      Group {
        WorkspaceIllustration(kind: .quarters, size: size)
        WorkspaceIllustration(kind: .leftQuarters, size: size)
        WorkspaceIllustration(kind: .fill, size: size)
        WorkspaceIllustration(kind: .rightQuarters, size: size)
      }
      .compositingGroup()
      .shadow(radius: 2, y: 2)
      .frame(width: size / 1.75, height: size / 1.75)
    }
    .padding(.vertical, size * 0.2)
    .offset(x: size * 0.3125)
  }
}

struct WorkspaceIllustration: View {
  enum Kind {
    case leftQuarters
    case quarters
    case rightQuarters
    case fill
  }
  let kind: Kind
  let size: CGFloat
  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.125)
      .fill(Color.white.opacity(0.4))
      .clipShape(RoundedRectangle(cornerRadius: size * 0.125))
      .overlay {
        ZStack {
          switch kind {
          case .leftQuarters: WorkspaceLeftQuarters(size: size)
          case .quarters: WorkspaceQuarters(size: size)
          case .rightQuarters: WorkspaceRightQuarters(size: size)
          case .fill: WorkspaceFill(size: size)
          }
        }
      }
  }
}

fileprivate struct WorkspaceQuarters: View {
  let size: CGFloat
  var body: some View {
    let cornerRadius: CGFloat = size * 0.0015
    let opacity: CGFloat = 0.8
    let spacing = size * 0.045
    let clipShapeSize = size * 0.045
    HStack(spacing: spacing) {
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
    }
    .padding(spacing)
  }
}

fileprivate struct WorkspaceLeftQuarters: View {
  let size: CGFloat
  var body: some View {
    let cornerRadius: CGFloat = size * 0.0015
    let opacity: CGFloat = 0.8
    let spacing = size * 0.045
    let clipShapeSize = size * 0.045
    HStack(spacing: spacing) {
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(1))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(0.6))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
    }
    .padding(spacing)
  }
}

fileprivate struct WorkspaceRightQuarters: View {
  let size: CGFloat
  var body: some View {
    let cornerRadius: CGFloat = size * 0.0015
    let opacity: Double = 0.8
    let spacing = size * 0.045
    let clipShapeSize = size * 0.045
    HStack(spacing: spacing) {
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
      VStack(spacing: spacing) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.white.opacity(opacity))
          .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
      }
    }
    .padding(spacing)
  }
}


fileprivate struct WorkspaceFill: View {
  let size: CGFloat
  var body: some View {
    let cornerRadius: CGFloat = size * 0.065
    let spacing = size * 0.045
    let clipShapeSize = size * 0.045
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(Color.white.opacity(0.8))
      .clipShape(RoundedRectangle(cornerRadius: clipShapeSize))
    .padding(spacing)
  }
}


#Preview {
  IconPreview { WorkspaceIcon(size: $0) }
}

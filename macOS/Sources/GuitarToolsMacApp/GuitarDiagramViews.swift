import GuitarToolsCore
import SwiftUI

struct ChordShapeDiagram:
    View {

    let shape:
        GuitarChordShape

    var compact = false

    var body: some View {
        VStack(
            spacing: 5
        ) {
            Text(shape.name)
                .font(
                    compact
                    ? .headline
                    : .title3
                )
                .fontWeight(
                    .semibold
                )

            Canvas {
                context,
                size in

                let top: CGFloat =
                    20
                let bottom: CGFloat =
                    8

                let left: CGFloat =
                    18
                let right: CGFloat =
                    18

                let width =
                    size.width -
                    left -
                    right

                let height =
                    size.height -
                    top -
                    bottom

                let stringGap =
                    width / 5

                let fretCount = 5

                let fretGap =
                    height /
                    CGFloat(fretCount)

                for string in 0..<6 {
                    let x =
                        left +
                        CGFloat(string) *
                        stringGap

                    context.stroke(
                        Path {
                            path in

                            path.move(
                                to:
                                    CGPoint(
                                        x: x,
                                        y: top
                                    )
                            )

                            path.addLine(
                                to:
                                    CGPoint(
                                        x: x,
                                        y:
                                            top +
                                            height
                                    )
                            )
                        },
                        with:
                            .foreground,
                        lineWidth: 1
                    )
                }

                for fret in
                    0...fretCount {
                    let y =
                        top +
                        CGFloat(fret) *
                        fretGap

                    context.stroke(
                        Path {
                            path in

                            path.move(
                                to:
                                    CGPoint(
                                        x: left,
                                        y: y
                                    )
                            )

                            path.addLine(
                                to:
                                    CGPoint(
                                        x:
                                            left +
                                            width,
                                        y: y
                                    )
                            )
                        },
                        with:
                            .foreground,
                        lineWidth:
                            fret == 0 &&
                            shape.baseFret ==
                            1
                            ? 3
                            : 1
                    )
                }

                for barre in shape.barres {
                    let displayFret =
                        barre.fret -
                        shape.baseFret +
                        1

                    guard
                        displayFret >= 1,
                        displayFret <=
                            fretCount
                    else {
                        continue
                    }

                    let firstIndex =
                        max(
                            min(
                                barre.fromString - 1,
                                5
                            ),
                            0
                        )

                    let lastIndex =
                        max(
                            min(
                                barre.toString - 1,
                                5
                            ),
                            0
                        )

                    let startX =
                        left +
                        CGFloat(
                            min(
                                firstIndex,
                                lastIndex
                            )
                        ) *
                        stringGap

                    let endX =
                        left +
                        CGFloat(
                            max(
                                firstIndex,
                                lastIndex
                            )
                        ) *
                        stringGap

                    let y =
                        top +
                        (
                            CGFloat(
                                displayFret
                            ) -
                            0.5
                        ) *
                        fretGap

                    context.stroke(
                        Path {
                            path in

                            path.move(
                                to:
                                    CGPoint(
                                        x: startX,
                                        y: y
                                    )
                            )
                            path.addLine(
                                to:
                                    CGPoint(
                                        x: endX,
                                        y: y
                                    )
                            )
                        },
                        with:
                            .foreground,
                        style:
                            StrokeStyle(
                                lineWidth:
                                    compact
                                    ? 7
                                    : 9,
                                lineCap:
                                    .round
                            )
                    )
                }

                for (
                    arrayIndex,
                    fret
                ) in shape
                    .frets
                    .enumerated() {

                    let stringIndex =
                        5 -
                        arrayIndex

                    let x =
                        left +
                        CGFloat(
                            stringIndex
                        ) *
                        stringGap

                    if fret < 0 {
                        drawText(
                            "×",
                            at:
                                CGPoint(
                                    x: x,
                                    y: 7
                                ),
                            context:
                                &context
                        )

                        continue
                    }

                    if fret == 0 {
                        drawText(
                            "○",
                            at:
                                CGPoint(
                                    x: x,
                                    y: 7
                                ),
                            context:
                                &context
                        )

                        continue
                    }

                    let displayFret =
                        fret -
                        shape.baseFret +
                        1

                    guard
                        displayFret >= 1,
                        displayFret <=
                            fretCount
                    else {
                        continue
                    }

                    let y =
                        top +
                        (
                            CGFloat(
                                displayFret
                            ) -
                            0.5
                        ) *
                        fretGap

                    let radius:
                        CGFloat =
                        compact
                        ? 5
                        : 7

                    let ellipse =
                        Path(
                            ellipseIn:
                                CGRect(
                                    x:
                                        x -
                                        radius,
                                    y:
                                        y -
                                        radius,
                                    width:
                                        radius *
                                        2,
                                    height:
                                        radius *
                                        2
                                )
                        )

                    context.fill(
                        ellipse,
                        with:
                            .foreground
                    )

                    if
                        let finger =
                            shape
                                .fingers[
                                    arrayIndex
                                ],
                        !compact {
                        let text =
                            Text(
                                "\(finger)"
                            )
                            .font(
                                .system(
                                    size: 9,
                                    weight:
                                        .bold
                                )
                            )
                            .foregroundStyle(
                                Color
                                    .white
                            )

                        context.draw(
                            text,
                            at:
                                CGPoint(
                                    x: x,
                                    y: y
                                )
                        )
                    }
                }

                if shape.baseFret > 1 {
                    context.draw(
                        Text(
                            "\(shape.baseFret)fr"
                        )
                        .font(
                            .caption2
                        ),
                        at:
                            CGPoint(
                                x: 2,
                                y:
                                    top +
                                    fretGap /
                                    2
                            ),
                        anchor:
                            .leading
                    )
                }
            }
            .frame(
                height:
                    compact
                    ? 118
                    : 155
            )
        }
    }

    private func drawText(
        _ value: String,
        at point: CGPoint,
        context:
            inout GraphicsContext
    ) {
        context.draw(
            Text(value)
                .font(.caption),
            at: point
        )
    }
}

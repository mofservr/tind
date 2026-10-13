import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    function nextSlide() { presentation.goToNextSlide(); }

    Timer {
        id: advanceTimer
        interval: 9000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0C1523" }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#E8F3F8"; font.pixelSize: 30
            text: "Welcome to Tind\n\nA calm, fast desktop.\nCold mountain, warm welcome."
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#0C1523" }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#E8F3F8"; font.pixelSize: 26
            text: "Built on Debian\n\nStable at its core, with no bloat and no surprises."
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#0C1523" }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#F6A9BC"; font.pixelSize: 26
            text: "Almost there\n\nAfter the first start, open Tind Apps\nto add Steam, Spotify and more."
        }
    }
}

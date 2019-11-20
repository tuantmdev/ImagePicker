import UIKit

// MARK: - BottomContainer autolayout

extension BottomContainerView {

  func setupConstraints() {

    for attribute: NSLayoutConstraint.Attribute in [.centerX, .centerY] {
      addConstraint(NSLayoutConstraint(item: pickerButton, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))

      addConstraint(NSLayoutConstraint(item: borderPickerButton, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))
    }

    for attribute: NSLayoutConstraint.Attribute in [.height, .bottom, .left] {
      addConstraint(NSLayoutConstraint(item: topSeparator, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))
    }

    for attribute: NSLayoutConstraint.Attribute in [.width, .height] {
      addConstraint(NSLayoutConstraint(item: pickerButton, attribute: attribute,
        relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
        multiplier: 1, constant: ButtonPicker.Dimensions.buttonSize))

      addConstraint(NSLayoutConstraint(item: borderPickerButton, attribute: attribute,
        relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
        multiplier: 1, constant: ButtonPicker.Dimensions.buttonBorderSize))

      addConstraint(NSLayoutConstraint(item: stackView, attribute: attribute,
        relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
        multiplier: 1, constant: ImageStackView.Dimensions.imageSize))
    }

    addConstraint(NSLayoutConstraint(item: doneButton, attribute: .centerX,
      relatedBy: .equal, toItem: self, attribute: .centerX,
      multiplier: 1, constant: 0))

    addConstraint(NSLayoutConstraint(item: stackView, attribute: .centerX,
      relatedBy: .equal, toItem: self, attribute: .centerX,
      multiplier: 1, constant: -2))

    let screenSize = Helper.screenSizeForOrientation()

    addConstraint(NSLayoutConstraint(item: doneButton, attribute: .centerY,
      relatedBy: .equal, toItem: self, attribute: .top,
      multiplier: 1, constant: (screenSize.height - (ButtonPicker.Dimensions.buttonBorderSize + screenSize.height)/2)/2))

    addConstraint(NSLayoutConstraint(item: stackView, attribute: .centerY,
      relatedBy: .equal, toItem: self, attribute: .bottom,
      multiplier: 1, constant: -(screenSize.height/4 - ButtonPicker.Dimensions.buttonBorderSize/3)))

    addConstraint(NSLayoutConstraint(item: topSeparator, attribute: .width,
      relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
      multiplier: 1, constant: 1))
  }
}

// MARK: - TopView autolayout

extension TopView {

  func setupConstraints() {
    
    addConstraint(NSLayoutConstraint(item: flashButton, attribute: .left,
                                     relatedBy: .equal, toItem: self, attribute: .left,
                                     multiplier: 1, constant: 6))
    
    addConstraint(NSLayoutConstraint(item: flashButton, attribute: .bottom,
                                     relatedBy: .equal, toItem: self, attribute: .bottom,
                                     multiplier: 1, constant: 0))

    addConstraint(NSLayoutConstraint(item: flashButton, attribute: .width,
      relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
      multiplier: 1, constant: 55))
    
    addConstraint(NSLayoutConstraint(item: flashButton, attribute: .height,
                                     relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
                                     multiplier: 1, constant: 55))

    if configuration.canRotateCamera {
      addConstraint(NSLayoutConstraint(item: rotateCamera, attribute: .top,
        relatedBy: .equal, toItem: self, attribute: .top,
        multiplier: 1, constant: Dimensions.rightOffset))

      addConstraint(NSLayoutConstraint(item: rotateCamera, attribute: .centerX,
        relatedBy: .equal, toItem: self, attribute: .centerX,
        multiplier: 1, constant: 0))

      addConstraint(NSLayoutConstraint(item: rotateCamera, attribute: .width,
        relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
        multiplier: 1, constant: 55))

      addConstraint(NSLayoutConstraint(item: rotateCamera, attribute: .height,
        relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
        multiplier: 1, constant: 55))
    }
  }
}

// MARK: - Controller autolayout

extension ImagePickerController {

  func setupConstraints() {
    let attributes: [NSLayoutConstraint.Attribute] = [.bottom, .right, .top]
    let topViewAttributes: [NSLayoutConstraint.Attribute] = [.top, .bottom]

    for attribute in attributes {
      view.addConstraint(NSLayoutConstraint(item: bottomContainer, attribute: attribute,
        relatedBy: .equal, toItem: view, attribute: attribute,
        multiplier: 1, constant: 0))
    }

    for attribute: NSLayoutConstraint.Attribute in [.left, .top, .bottom] {
      view.addConstraint(NSLayoutConstraint(item: cameraController.view, attribute: attribute,
        relatedBy: .equal, toItem: view, attribute: attribute,
        multiplier: 1, constant: 0))
    }

    for attribute in topViewAttributes {
      view.addConstraint(NSLayoutConstraint(item: topView, attribute: attribute,
        relatedBy: .equal, toItem: self.view, attribute: attribute,
        multiplier: 1, constant: 0))
    }

    if #available(iOS 11.0, *) {
      view.addConstraint(NSLayoutConstraint(item: topView, attribute: .left,
                                            relatedBy: .equal, toItem: view.safeAreaLayoutGuide,
                                            attribute: .left,
                                            multiplier: 1, constant: 0))
    } else {
      view.addConstraint(NSLayoutConstraint(item: topView, attribute: .left,
                                            relatedBy: .equal, toItem: view,
                                            attribute: .left,
                                            multiplier: 1, constant: 0))
    }
    
    if #available(iOS 11.0, *) {
      let heightPadding = UIApplication.shared.keyWindow!.safeAreaInsets.bottom
      view.addConstraint(NSLayoutConstraint(item: bottomContainer, attribute: .width,
                                            relatedBy: .equal, toItem: nil,
                                            attribute: .notAnAttribute,
                                            multiplier: 1,
                                            constant: BottomContainerView.Dimensions.height + heightPadding))
    } else {
      view.addConstraint(NSLayoutConstraint(item: bottomContainer, attribute: .width,
                                            relatedBy: .equal, toItem: nil,
                                            attribute: .notAnAttribute,
                                            multiplier: 1,
                                            constant: BottomContainerView.Dimensions.height))
    }

    view.addConstraint(NSLayoutConstraint(item: topView, attribute: .width,
      relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
      multiplier: 1, constant: TopView.Dimensions.height))

    view.addConstraint(NSLayoutConstraint(item: cameraController.view, attribute: .width,
      relatedBy: .equal, toItem: view, attribute: .width,
      multiplier: 1, constant: -BottomContainerView.Dimensions.height))
  }
}

extension ImageGalleryViewCell {

  func setupConstraints() {

    for attribute: NSLayoutConstraint.Attribute in [.width, .height, .centerX, .centerY] {
      addConstraint(NSLayoutConstraint(item: imageView, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))

      addConstraint(NSLayoutConstraint(item: selectedImageView, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))
    }
  }
}

extension ButtonPicker {

  func setupConstraints() {
    let attributes: [NSLayoutConstraint.Attribute] = [.centerX, .centerY]

    for attribute in attributes {
      addConstraint(NSLayoutConstraint(item: numberLabel, attribute: attribute,
        relatedBy: .equal, toItem: self, attribute: attribute,
        multiplier: 1, constant: 0))
    }
  }
}

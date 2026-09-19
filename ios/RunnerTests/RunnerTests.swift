import Flutter
import UIKit
import XCTest
import NVEasySDK

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }
  
  func testOTAManagerInitialization() {
    // 测试OTA管理器是否正确初始化
    let otaManager = NVEasyOTAManager.shared
    XCTAssertNotNil(otaManager, "OTA manager should not be nil")
    XCTAssertNotNil(otaManager.bleManager, "OTA manager should have a BLE manager")
  }
  
  func testOTAUpgradeMethodExists() {
    // 测试OTA升级方法是否存在
    let otaManager = NVEasyOTAManager.shared
    let method = #selector(NVEasyOTAManager.upgrade(to:with:pkgSize:))
    XCTAssertTrue(otaManager.responds(to: method), "OTA manager should respond to upgrade method")
  }

}

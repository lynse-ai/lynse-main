import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class PaymentSuccessPage extends StatelessWidget {
  final String amount; // 支付金额

  const PaymentSuccessPage({Key? key, required this.amount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Stack(children: [_buildBackground(), _buildContent()]),
    );
  }

  // 构建顶部导航栏
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        padding: EdgeInsets.only(left: 12.w, right: 18.w),
        child: GestureDetector(
          onTap: () {
            NavigationUtils.back();
          },
          child: Image.asset(
            'assets/images_v3/back.png',
            width: 20.w,
            height: 20.w,
          ),
        ),
      ),
    );
  }

  // 构建背景图案
  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/vip/payment_bg.png'),
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  // 构建主要内容
  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 支付成功图标
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString('#7857ED'),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ColorUtil.fromHexString('#7857ED', 0.3),
                  blurRadius: 20.w,
                  spreadRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check, color: Colors.white, size: 60.w),
          ),
          SizedBox(height: 40.w),

          // 支付金额
          Text(
            '¥$amount',
            style: TextStyle(
              fontSize: 42.w,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 20.w),

          // 支付成功文本
          Text(
            '支付成功',
            style: TextStyle(
              fontSize: 22.w,
              color: ColorUtil.fromHexString('#7857ED'),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 120.w),

          // 返回按钮
          Container(
            width: 300.w,
            height: 68.w,
            child: ElevatedButton(
              onPressed: () {
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtil.fromHexString('#7857ED'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(34.w),
                ),
                elevation: 0,
              ),
              child: Text(
                '返回',
                style: TextStyle(
                  fontSize: 18.w,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

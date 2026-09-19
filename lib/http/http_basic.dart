import 'package:dio/dio.dart';
// import 'package:dio_log/dio_log.dart';

const _endpoint = 'http://dting.geekdance.com.cn'; //生产环境
// const _endpoint = 'http://dting-dev.geekdance.com.cn'; //测试环境
// const _endpoint = 'http://47.113.105.200:10060';
// const _endpoint = 'http://192.168.112.73:10060'; //支付测试环境
// const _endpoint = 'http://192.168.112.152:10060'; //支付测试环境

String token = '';

final options = BaseOptions(
  baseUrl: _endpoint,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 60),
  contentType: Headers.jsonContentType,
);
// final dio = Dio(options)..interceptors.add(DioLogInterceptor());
final dio = Dio(options);

// Copyright (c) 2015-2021 MinIO, Inc.
//
// This file is part of MinIO Object Storage stack
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

package cmd

import (
	"net/http"

	"github.com/minio/minio/internal/grid"
	"github.com/minio/mux"
)

// Composed function registering routers for only distributed Erasure setup.
func registerDistErasureRouters(router *mux.Router, endpointServerPools EndpointServerPools) {
	var (
		lockGrid   = globalLockGrid.Load()
		commonGrid = globalGrid.Load()
	)

	// Register storage REST router only if its a distributed setup.
	registerStorageRESTHandlers(router, endpointServerPools, commonGrid)

	// Register peer REST router only if its a distributed setup.
	registerPeerRESTHandlers(router, commonGrid)

	// Register bootstrap REST router for distributed setups.
	registerBootstrapRESTHandlers(commonGrid)

	// Register distributed namespace lock routers.
	registerLockRESTHandlers(lockGrid)

	// Add lock grid to router
	router.Handle(grid.RouteLockPath, adminMiddleware(lockGrid.Handler(storageServerRequestValidate), noGZFlag, noObjLayerFlag))

	// Add grid to router
	router.Handle(grid.RoutePath, adminMiddleware(commonGrid.Handler(storageServerRequestValidate), noGZFlag, noObjLayerFlag))
}

// List of some generic middlewares which are applied for all incoming requests.
var globalMiddlewares = []mux.MiddlewareFunc{
	// set x-amz-request-id header and others
	addCustomHeadersMiddleware,
	// The generic tracer needs to be the first middleware to catch all requests
	// returned early by any other middleware (but after the middleware that
	// sets the amz request id).
	httpTracerMiddleware,
	// Auth middleware verifies incoming authorization headers and routes them
	// accordingly. Client receives a HTTP error for invalid/unsupported
	// signatures.
	//
	// Validates all incoming requests to have a valid date header.
	setAuthMiddleware,
	// Redirect some pre-defined browser request paths to a static location
	// prefix.
	setBrowserRedirectMiddleware,
	// Adds 'crossdomain.xml' policy middleware to serve legacy flash clients.
	setCrossDomainPolicyMiddleware,
	// Limits all body and header sizes to a maximum fixed limit
	setRequestLimitMiddleware,
	// Validate all the incoming requests.
	setRequestValidityMiddleware,
	// Add upload forwarding middleware for site replication
	setUploadForwardingMiddleware,
	// Add bucket forwarding middleware
	setBucketForwardingMiddleware,
	// Add new middlewares here.
}

// configureServer handler returns final handler for the http server.
func configureServerHandler(endpointServerPools EndpointServerPools) (http.Handler, error) {
	// Initialize router. `SkipClean(true)` stops minio/mux from
	// normalizing URL path minio/minio#3256
	// mabing: .SkipClean(true): 跳过路径清理功能。
	// 通常路由器会自动清理 URL 路径（比如将 // 转换为 /，移除 . 和 .. 等），但设置为 true 后会保持原始路径不变。
	// mabing: .UseEncodedPath(): 使用编码后的路径进行路由匹配。这意味着路由器会使用 URL 编码后的原始路径进行匹配，
	// 而不是解码后的路径。这确保了包含特殊字符（如空格、中文字符等）的对象名称能够正确处理。
	router := mux.NewRouter().SkipClean(true).UseEncodedPath()

	// Initialize distributed NS lock.
	if globalIsDistErasure {
		registerDistErasureRouters(router, endpointServerPools)
	}

	// Add Admin router, all APIs are enabled in server mode.
	registerAdminRouter(router, true)

	// Add healthCheck router
	registerHealthCheckRouter(router)

	// Add server metrics router
	registerMetricsRouter(router)

	// Add STS router always.
	registerSTSRouter(router)

	// Add KMS router
	registerKMSRouter(router)

	// Add API router
	registerAPIRouter(router)

	router.Use(globalMiddlewares...)

	return router, nil
}

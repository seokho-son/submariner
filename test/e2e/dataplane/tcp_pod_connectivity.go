package dataplane

import (
	. "github.com/onsi/ginkgo"
	"github.com/submariner-io/submariner/test/e2e/framework"
	"github.com/submariner-io/submariner/test/e2e/tcp"
)

const basicDataplaneTimeoutMultiplier = 1

var _ = Describe("[dataplane] Basic TCP connectivity tests across clusters without discovery", func() {
	f := framework.NewDefaultFramework("dataplane-conn-nd")
	var useService bool
	var networkType bool

	verifyInteraction := func(listenerScheduling, connectorScheduling framework.NetworkPodScheduling) {
		It("should have sent the expected data from the pod to the other pod", func() {
			tcp.RunConnectivityTest(f, useService, networkType, listenerScheduling, connectorScheduling, framework.ClusterB, framework.ClusterA, basicDataplaneTimeoutMultiplier)
		})
	}

	When("a pod connects via TCP to a remote pod", func() {
		BeforeEach(func() {
			useService = false
			networkType = framework.PodNetworking
		})

		When("the pod is not on a gateway and the remote pod is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.NonGatewayNode)
		})

		When("the pod is not on a gateway and the remote pod is on a gateway", func() {
			verifyInteraction(framework.GatewayNode, framework.NonGatewayNode)
		})

		When("the pod is on a gateway and the remote pod is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.GatewayNode)
		})

		When("the pod is on a gateway and the remote pod is on a gateway", func() {
			verifyInteraction(framework.GatewayNode, framework.GatewayNode)
		})
	})

	When("a pod connects via TCP to a remote service", func() {
		BeforeEach(func() {
			useService = true
			networkType = framework.PodNetworking
		})

		When("the pod is not on a gateway and the remote service is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.NonGatewayNode)
		})

		When("the pod is not on a gateway and the remote service is on a gateway", func() {
			verifyInteraction(framework.GatewayNode, framework.NonGatewayNode)
		})

		When("the pod is on a gateway and the remote service is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.GatewayNode)
		})

		When("the pod is on a gateway and the remote service is on a gateway", func() {
			verifyInteraction(framework.GatewayNode, framework.GatewayNode)
		})
	})

	When("a pod with HostNetworking connects via TCP to a remote pod", func() {
		BeforeEach(func() {
			useService = false
			networkType = framework.HostNetworking
		})

		When("the pod is not on a gateway and the remote pod is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.NonGatewayNode)
		})

		When("the pod is on a gateway and the remote pod is not on a gateway", func() {
			verifyInteraction(framework.NonGatewayNode, framework.GatewayNode)
		})
	})
})

'use strict'

const h = require('chainlink-test-helpers')
const { BN, constants, expectEvent, expectRevert } = require('openzeppelin-test-helpers')

contract('ShippingContract', accounts => {
  const LinkToken = artifacts.require('LinkToken.sol')
  const Oracle = artifacts.require('Oracle.sol')
  const Reference = artifacts.require('MockAggregator.sol')
  const ShippingContract = artifacts.require('ShippingContract.sol')

  const defaultAccount = accounts[0]
  const oracleNode = accounts[1]
  const stranger = accounts[2]
  const maintainer = accounts[3]
  const buyer = accounts[4]
  const seller = accounts[5]

  const jobId = web3.utils.toHex('4c7b7ffb66b344fbaa64995af81e355a')

  // Represents 1 LINK for testnet requests
  const payment = web3.utils.toWei('1')

  let link, oc, cc, ref

  beforeEach(async () => {
    link = await LinkToken.new()
    ref = await Reference.new()
    oc = await Oracle.new(link.address, { from: defaultAccount })
    cc = await ShippingContract.new(
      link.address,
      oc.address,
      ref.address,
      jobId,
      payment,
      { from: maintainer })
    await oc.setFulfillmentPermission(oracleNode, true, {
      from: defaultAccount
    })
  })

  describe('updateOracleDetails', () => {
    const newJobId = web3.utils.toHex('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    const newPayment = web3.utils.toWei('2')
  
    context('when called by a stranger', () => {
      it('reverts', async () => {
        await expectRevert.unspecified(cc.updateOracleDetails(
          oc.address,
          ref.address,
          newJobId,
          newPayment,
          {from: stranger}
        ))
      })
    })

    context('when called by the owner', () => {
      it('should update the details', async () => {
        await cc.updateOracleDetails(
          oc.address,
          ref.address,
          newJobId,
          newPayment,
          {from: maintainer}
        )
        assert.equal(await cc.jobId(), newJobId)
        assert.equal(await cc.payment(), newPayment)
      })
    })
  })

  describe('createOrder', () => {
    context('with an invalid amount', () => {
      it('reverts', async () => {

      })
    })

    context('with a valid amount', () => {
      it('should create an order', async () => {

      })
    })

    context('if the order already exists', () => {
      it('reverts', async () => {
        
      })
    })
  })

  describe('payForOrder', () => {
    context('when the order doesnt exist', () => {
      it('reverts', async () => {

      })
    })

    context('when called by a non-buyer', () => {
      it('reverts', async () => {

      })
    })

    context('when the deadline has passed', () => {
      it('reverts', async () => {

      })
    })

    context('when the payment amount meets the order', () => {
      it('should pay for the order and send the remaining to the buyer', async () => {

      })
    })

    context('when the order has already been paid for', () => {
      it('reverts', async () => {
        
      })
    })
  })

  describe('cancelOrder', () => {
    context('when called by a non-party', () => {
      it('reverts', async () => {

      })
    })

    context('when the deadline has not been met', () => {
      it('reverts', async () => {

      })
    })

    context('when the deadline has passed', () => {
      it('should cancel the order', async () => {

      })
    })
  })

  describe('checkShippingStatus', () => {
    context('when the contract is not funded with LINK', () => {
      it('reverts', async () => {

      })
    })

    context('when the order does not exist', () => {
      it('reverts', async () => {

      })
    })

    context('when the order has not been paid for', () => {
      it('reverts', async () => {

      })
    })

    context('when the order is valid and paid for', () => {
      it('should create a Chainlink request', async () => {

      })
    })
  })

  describe('finalizeOrder', () => {
    context('when the status is delivered', () => {
      it('should pay the seller', async () => {

      })
    })

    context('when the status is return_to_sender', () => {
      it('should refund the buyer', async () => {

      })
    })
  })
})

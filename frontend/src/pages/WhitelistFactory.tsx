import React from "react"
import { Formik, Form, Field, FieldArray } from "formik"
import { Link } from "react-router-dom"

export const AddressList = () => (
  <div>
    <Formik
      initialValues={{ addresses: [] }}
      onSubmit={(values) => {
        setTimeout(() => {
          alert(JSON.stringify(values, null, 2))
        }, 500)
      }}
    >
      {({ values }) => (
        <Form>
          <FieldArray
            name="addresses"
            render={(arrayHelpers) => (
              <div>
                {values.addresses.map((_, index) => (
                  <div key={index}>
                    <Field name={`addresses.${index}`} />
                    <button
                      type="button"
                      onClick={() => arrayHelpers.remove(index)} // remove a friend from the list
                    >
                      -
                    </button>
                  </div>
                ))}
                <button type="button" onClick={() => arrayHelpers.push("")}>
                  Add an address
                </button>
                <div>
                  <button type="submit">Submit</button>
                </div>
              </div>
            )}
          />
        </Form>
      )}
    </Formik>
  </div>
)

const WhitelistFactory: React.FC = () => {
  return (
    <div>
      <Link to={"/"}> Go back home</Link>
      <h1>Create a whitelist</h1>
      <p>Input the signers, they are ethereum wallets</p>
      <AddressList />
    </div>
  )
}

export default WhitelistFactory

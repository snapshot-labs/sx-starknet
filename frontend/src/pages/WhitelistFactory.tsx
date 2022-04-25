import React from "react"
import { Formik, Form, Field, FieldArray } from "formik"

export const AddressList = () => (
  <div>
    <Formik
      initialValues={{ addresses: [] }}
      onSubmit={(values) => {
        setTimeout(() => {
          alert(JSON.stringify(values, null, 2))
        }, 500)
      }}
      render={({ values }) => (
        <Form>
          <FieldArray
            name="addresses"
            render={(arrayHelpers) => (
              <div>
                {values.addresses.map((friend, index) => (
                  <div key={index}>
                    <Field name={`address.${index}`} />
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
    />
  </div>
)

const WhitelistFactory: React.FC = () => {
  return <AddressList />
}

export default WhitelistFactory

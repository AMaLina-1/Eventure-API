# Eventure

A web application that helps users discover **events** and **activities** happening in Hsinchu City.

## API Introduction

### Hshinchu City Government Web OpenAPI

- Introduction: Getting activity information from Hsinchu government.
- Request URL:
  
  ```
  https://webopenapi.hccg.gov.tw/v1/Activity?top=100
  ```
  
    - `top`: The number of records to return (Maximum = 100)
- Request Header:
    
    ```
    {
      "Accept": "application/json"
    }
    ```
    
- Response Data
    
    After calling thie API, it will return the detail of the activities, and here are some infromation that might be helpful for our final project.

    - **Issuing Unit**: Refers to the organization that hosts or announces activities.  
    - **Activity**: Represents the event or program users can attend. 
    - **Organizer**: The main entity responsible for hosting the event.  
    - **Co-organizer**: Additional entities that assist in hosting the event.  
    - **Location**: Where the event takes place.  
    - **Start Date** / **End Date**: The schedule of the event.  
    - **Details**: Additional information describing the event.  
    - **Classification**: Used to categorize events based on two types:
      - **Subject Classification**: Describes the theme or topic of the event (e.g., culture, education, sports).  
      - **Service Classification**: Describes the target audience or service category (e.g., general public, youth, elderly).

- Entity-Relationship Diagram

  <table>
    <tr>
      <td><img src = 'images/ERD.png' width = '700'></td>
    </tr>

  </table>

## Context Description
Our application provides a **one-stop event discovery platform** that helps users easily find `activities` they like. Instead of visiting multiple resources, users can search for activities through our unified interface. Our main features include:
- Allowing users to apply `filters` such as `date`, `theme`, and `region` to quickly find relevant activities.
- Providing a `save` option for users to save those activities they are interested in during a browsing session.
- Enabling a `like` feature that allows users to express interest in activities, and the system displays their popularity based on the total number of likes.


## User Instruction

1. Use `bundle install` to install all required gems.

2. Register an AWS account and create an SQS queue. Fill in the required AWS credentials and SQS configuration in `config/secrets_sample.yml`, then rename it to `config/secrets.yml`.

3. Create database by `rake db:migrate`.

4. Run background worker by `rake worker:run:dev`.

5. Run api-Eventure program by `rake run`.
